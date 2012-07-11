require 'rubygems'
require './osm'
require './db'
require './actions'
require './tags'
require './geom'
require 'set'

class History
  def initialize(versions, db)
    @versions, @db = versions, db

    # just get objects in ascending version order
    @versions.sort_by! {|obj| obj.version}
  end

  def odbl_clean_versions
    # we need to track odbl clean-ness. if the tag is set and
    # later unset, then we consider it a mistake.

    # first, figure out which versions are clean.
    version_is_clean = @versions.map {|obj| Tags.odbl_clean?(obj.tags)}

    # iterate backwards, propagating uncleanness where the
    # flag is reset.
    global = true
    version_is_clean.reverse.map {|flag| global = flag && global}.reverse
  end

  def whitelisted_versions
    obj = @versions.first
    id_str = if obj.class == OSM::Node
               'n'
             elsif obj.class == OSM::Way
               'w'
             else
               'r'
             end + obj.element_id.to_s + 'v'
    @versions.map {|v| @db.edit_whitelist.include?(id_str + v.version.to_s)}
  end

  def blacklisted_versions
    obj = @versions.first
    id_str = if obj.class == OSM::Node
               'n'
             elsif obj.class == OSM::Way
               'w'
             else
               'r'
             end + obj.element_id.to_s + 'v'
    @versions.map {|v| @db.edit_blacklist.include?(id_str + v.version.to_s)}
  end

  def actions
    accepted_versions = @versions.map {|obj| changeset_is_accepted? obj.changeset_id}
  
    return [] if accepted_versions.all?

    prev_obj = @versions.first.version_zero

    base_obj = prev_obj.clone
    xactions = Array.new
    diff_state = Array.new

    tainted_tags = Array.new
    omit_tags = []
    omit_tags = ["multipolygon", "route", "site", "restriction", "boundary"].map{|v| ["type", v]} if base_obj.class == OSM::Relation

    @versions.zip(odbl_clean_versions, accepted_versions, whitelisted_versions, blacklisted_versions).each do |obj,is_odbl_clean,accepted,is_whitelisted,is_blacklisted|
      # deletions are always "clean", and we consider them to
      # have no tags and the "version zero" geometry. what
      # happens after that may be a revert to a previous version.
      unless obj.visible
        base_obj.geom = base_obj.version_zero_geom
        base_obj.tags = {}
        prev_obj = base_obj
        next
      end

      # generate the diffs for geometry and tags separately
      geom_patch = Geom.diff(prev_obj, obj)
      tags_patch = Tags.diff(prev_obj, obj)

      # is this version clean? there are many ways to be
      # clean, and we try to enumerate them here.
      status = if is_odbl_clean
                 :odbl_clean
               elsif is_blacklisted
                 :unclean
               elsif accepted
                 :acceptor_edit
               elsif is_whitelisted
                 :whitelisted_version
               elsif tags_patch.empty? and geom_patch.empty?
                 :empty
               elsif tags_patch.trivial? and geom_patch.empty?
                 :trivial
               else
                 :unclean
               end

      # if this is not a clean version, then the only part
      # of the patch we can apply is the deletions, by the
      # 'deletions are always OK' rule.
      apply_options = (status == :unclean) ? {:only => :deleted} : {}
      apply_options[:state] = diff_state
      apply_options[:omit_tags] = omit_tags
      apply_options[:no_order] = (obj.class == OSM::Relation and base_obj.tags["type"] == "multipolygon")

      # if the element is explicitly marked as clean, then
      # don't bother with the application of patches, just
      # update the element.
      if status == :odbl_clean
        new_tags = obj.tags
        new_geom = obj.geom

        # also remove any of the current tags which are in 
        # the tainted set of tags - they're not tainted
        # any more if this is explicitly obdl clean.
        tainted_tags.delete_if {|k,v| new_tags[k] == v}

      else
        # apply the patches
        new_tags = tags_patch.apply(base_obj.tags, apply_options)
        new_geom = geom_patch.apply(base_obj.geom, apply_options)
        if apply_options[:no_order] and new_geom.sort == obj.geom.sort then
          new_geom = obj.geom
        end
      end

      # if the tags patch is unclean then record the additions and 
      # changes to check for taint later on.
      if status == :unclean
        # taint all created tags
        tainted_tags.concat(tags_patch.created.to_a)
        # taint the new version of any edited or moved tag
        tainted_tags.concat(tags_patch.edited.map {|k,vals| [k,vals[1]]})
        tainted_tags.concat(tags_patch.moved.map {|keys,v| [keys[1],v]})
        
        tainted_tags -= omit_tags
      end

      # remove any taint from the new tags
      tainted_tags.each do |k,v|
        new_tags.delete(k) if new_tags[k] == v
      end

      # if the result of applying the patches is any different
      # from the version we actually have, then the object is
      # in a state that we can't display, so redact it.
      if (new_tags != obj.tags || new_geom != obj.geom) #and 
        #not (geom_patch.only_deletes? and tags_patch.only_deletes?))
        visibility = ((status == :unclean) ?
                      tags_patch.only_deletes? && geom_patch.only_deletes? :
                      new_tags != base_obj.tags || new_geom != base_obj.geom || status == :acceptor_edit || status == :whitelisted_version || status == :empty)
        xactions << Redact[obj.class, obj.element_id, obj.version, visibility ? :visible : :hidden]
      end
      
      # update object
      base_obj.geom = new_geom
      base_obj.tags = new_tags

      prev_obj = obj
    end

    if base_obj.invalid?
      if @versions.last.visible
        xactions.insert(0, Delete[base_obj.class, base_obj.element_id])
      end

    elsif ((base_obj.tags != @versions.last.tags) or
        ((base_obj.geom != @versions.last.geom) and
        ((base_obj.class != OSM::Node) or not Geom::close?(base_obj.geom, @versions.last.geom))))
      base_obj.changeset_id = -1
      base_obj.version = @versions.last.version

      # strip out AUTO_KEYS if we're doing an edit anyway
      base_obj.tags.select! {|k,v| not Tags::AUTO_KEYS.include? k}

      xactions.insert(0, Edit[base_obj])
    end
    
    return xactions
  end

  private

  def changeset_is_accepted?(changeset_id)
    cs = @db.changeset(changeset_id)
    accepted = cs.user.accepted_cts? 
    accepted = accepted or (not cs.user.adopter.nil? and cs.user.adopter.accepted_cts?)
    accepted = accepted or cs.override_accepted?
    return accepted
  end
end

class ChangeBot
  attr_reader :redactions

  def initialize(db)
    @db = db
    @pending_deletes = Array.new
    @pending_edits = Array.new
    @redactions = Array.new
  end

  def action_for(history)
    # special case for excluded items
    klass = history.first.class
    element_id = history.first.element_id
    if @db.exclude?(klass, element_id)
      return [Delete[klass, element_id]] + history.map {|e| Redact[klass, element_id, e.version, :hidden]}
    end

    # otherwise, normal process.
    h = History.new(history, @db)
    # h.each_version do |element|
    #   if changeset_is_accepted?(element.changeset_id)
    #     if h.is_clean?
    #       h.merge_clean_onto_clean(element)
    #     else
    #       h.merge_clean_onto_dirty(element)
    #     end
    #   else
    #     h.merge_dirty(element)
    #   end
    # end
    h.actions
  end

  def process!(klass, elt_id)
    # grab history from the database
    history = if klass == OSM::Node
                @db.node(elt_id)
              elsif klass == OSM::Way
                @db.way(elt_id)
              elsif klass == OSM::Relation
                @db.relation(elt_id)
              end
    
    # get the actions for it
    actions = action_for(history)

    # split up the actions into edits, deletes and redactions
    actions.each do |act|
      case act 
      when Edit
        @pending_edits << act
      when Delete
        @pending_deletes << act
      when Redact
        @redactions << act
      end
    end
  end

  def process_all!
    process_nodes!
    process_ways!
    process_relations!
  end
  
  def process_nodes!
    @db.each_node     {|n| process!(OSM::Node, n)}
  end
  
  def process_ways!
    @db.each_way      {|w| process!(OSM::Way, w)}
  end
  
  def process_relations!
    @db.each_relation {|r| process!(OSM::Relation, r)}
  end

  def as_changeset
    changeset = Array.new

    # go over the pending deletes. each of these may affect other objects
    # which aren't even in the set of objects that we wanted to process. 
    # in that case, we'll need to create a new edit on that other object 
    # to remove the current object from it first.
    # 
    # in order to get this right we need to process the node deletions
    # first, then the way deletions, then the relation deletions. the 
    # reason for this is that a node deletion can affect ways and
    # relations, causing them to also be deleted. ways deletions, in turn, 
    # can cascade to relation deletions but, importantly, not to node 
    # deletions.
    #

    [OSM::Node, OSM::Way, OSM::Relation].each do |klass|
      @pending_deletes.select{ |del| del.klass == klass }.each{ |d| process_delete(d) }
    end

    # we should now be OK to do the edits, removing references to 
    # deleted objects.
    [OSM::Relation, OSM::Way, OSM::Node].each do |klass|
      @pending_edits.each do |edit|
        if edit.obj.class == klass
          changeset << edit
        end
      end
    end

    # having removed references, we should be OK to do the deletes
    [OSM::Relation, OSM::Way, OSM::Node].each do |klass|
      @pending_deletes.each do |del|
        if del.klass == klass
          changeset << del
        end
      end
    end
    return changeset
  end

  def process_delete(del)
    references = @db.objects_using(del.klass, del.element_id)
    
    references.each do |ref_obj|
      ref_id = [ref_obj.class, ref_obj.element_id]
      
      # if we're planning to delete this item anyway, then just leave
      # it - no need to alter that edit.
      unless @pending_deletes.detect{ |a| a.klass == ref_obj.class && a.element_id == ref_obj.element_id }
        # get the edit we're planning to do, if there is one, otherwise
        # the current object version.
        plan = @pending_edits.detect{ |a| a.obj.class == ref_obj.class && a.obj.element_id == ref_obj.element_id }
        edit = if plan
                 plan
               else
                 obj = ref_obj.clone
                 obj.changeset_id = -1
                 Edit[obj]
               end
        kill_object = false
        
        case edit.obj
        when OSM::Node
          raise Exception.new("Node found as referencing object. BUG!")
          
        when OSM::Way
          edit.obj.nodes.select! {|n| n != del.element_id}
          kill_object = edit.obj.nodes.size < 2
          
        when OSM::Relation
          edit.obj.members.select! {|m| m.type != del.klass || m.ref != del.element_id}
          # hmm... whether to kill empty relations or not? the test currently
          # says not, but i'm not sure an empty relation is actually particularly
          # useful to anyone
          # Actually, given there's a bug (or at the least, an ambiguity in the API),
          # we *need* to kill empty relations. They can't be uploaded without
          # a certain amount of gymnastics.
          # See https://trac.openstreetmap.org/ticket/4471
          kill_object = edit.obj.members.empty?
        end
        
        if kill_object
          @pending_edits.delete_if{|e| e.obj.class == ref_obj.class && e.obj.element_id == ref_obj.element_id}
          @pending_deletes.unshift(Delete[*ref_id])
          
        else
          @pending_edits.delete_if{|e| e.obj.class == edit.obj.class && e.obj.element_id == edit.obj.element_id}
          @pending_edits.unshift(edit)
        end
      end
    end
  end
end
