require 'rubygems'
require './osm'
require './db'
require './actions'
require './tags'
require 'set'

class History
  def initialize(versions)
    @versions = versions

    # just get objects in ascending version order
    @versions.sort_by! {|obj| obj.version}

    # prepend the "version zero" object.
    @versions.insert(0, @versions.first.version_zero)
  end

  def actions
    # generate the diffs for geometry and tags separately
    geom_patches = @versions.each_cons(2).map {|a, b| geom_diff(a, b)}
    tags_patches = @versions.each_cons(2).map {|a, b| Tags::Diff.new(a.tags, b.tags)}
    []
  end

  private

  def geom_diff(a, b)
  end
end

class ChangeBot
  attr_reader :redactions

  def initialize(db)
    @db = db
    @pending_deletes = Hash.new
    @pending_edits = Hash.new
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
    h = History.new(history)
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
        @pending_edits[[klass, elt_id]] = act
      when Delete
        @pending_deletes[[klass, elt_id]] = act
      when Redact
        @redactions << act
      end
    end
  end

  def process_all!
    @db.nodes.keys.each     {|n| process!(OSM::Node, n)}
    @db.ways.keys.each      {|w| process!(OSM::Way, w)}
    @db.relations.keys.each {|r| process!(OSM::Relation, r)}
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
      ids = Array.new

      @pending_deletes.each do |id, del|
        if id[0] == klass
          ids << id[1]
        end
      end
      
      ids.each {|i| process_delete([klass, i], @pending_deletes[[klass, i]])}
    end

    # we should now be OK to do the edits, removing references to 
    # deleted objects.
    [OSM::Relation, OSM::Way, OSM::Node].each do |klass|
      @pending_edits.each do |id, edit|
        if id[0] == klass 
          changeset << edit
        end
      end
    end

    # having removed references, we should be OK to do the deletes
    [OSM::Relation, OSM::Way, OSM::Node].each do |klass|
      @pending_deletes.each do |id, del|
        if id[0] == klass 
          changeset << del
        end
      end
    end

    return changeset
  end

  def process_delete(id, del)
    references = @db.objects_using(*id)
    
    references.each do |ref_obj|
      ref_id = [ref_obj.class, ref_obj.element_id]
      
      # if we're planning to delete this item anyway, then just leave
      # it - no need to alter that edit.
      unless @pending_deletes.has_key? ref_id
        # get the edit we're planning to do, if there is one, otherwise
        # the current object version.
        edit = if @pending_edits.has_key?(ref_id) 
                 @pending_edits[ref_id] 
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
          edit.obj.nodes.select! {|n| n != id[1]}
          kill_object = edit.obj.nodes.size < 2
          
        when OSM::Relation
          edit.obj.members.select! {|m| m.type != id[0] || m.ref != id[1]}
          # hmm... whether to kill empty relations or not? the test currently
          # says not, but i'm not sure an empty relation is actually particularly
          # useful to anyone
          #kill_object = edit.obj.members.empty?
        end
        
        if kill_object
          @pending_edits.delete ref_id
          @pending_deletes[ref_id] = Delete[*ref_id]
          
        else
          @pending_edits[ref_id] = edit
        end
      end
    end
  end

  def changeset_is_accepted?(changeset_id)
    cs = @db.changeset(changeset_id)
    accepted = cs.user.accepted_cts? 
    accepted = accepted or (not cs.user.adopter.nil? and cs.user.adopter.accepted_cts?)
    accepted = accepted or cs.override_accepted?
    return accepted
  end
end
