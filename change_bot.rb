require 'rubygems'
require './osm'
require './db'
require './actions'
require './tags'
require 'set'

class History
  def initialize(versions)
    # todo: ensure sort
    @versions = versions
    @tainted_tags = Hash.new
    @clean_values = Hash.new
    @cleans = Array.new
    @acceptors = Array.new
    @clean_geom = @versions.first.version_zero_geom
  end

  def each_version
    @versions.each do |v|
      yield v
    end
  end

  def merge_clean_onto_clean(obj)
    @cleans << true
    @acceptors << true
    @clean_values = obj.tags
    case obj
    when OSM::Node
      @clean_geom = obj.geom
    when OSM::Way
      @clean_geom = obj.nodes.map {|n| [n, true]}
    when OSM::Relation
      @clean_geom = obj.members.map {|m| [m, true]}
    end
  end

  def merge_clean_onto_dirty(obj)
    # merge any value changes for non-tainted keys into the 
    # tag set.
    is_fully_clean = true
    clean_tags = obj.tags.select do |k, v| 
      any_tainted = @tainted_tags.has_key?(k) && !Tags.significant_tag?(@tainted_tags[k], v)
      if any_tainted
        is_fully_clean = false
      end
      not any_tainted
    end
    # figure out what needs to happen with the geometry
    case obj
    when OSM::Node
      # ??? need to account for node movage?
      @clean_geom = obj.geom
    when OSM::Way
      old_nds, old_clean = @clean_geom.empty? ? [[],[]] : @clean_geom.transpose
      cur_nds, cur_clean = obj.nodes, obj.nodes.map { true }
      new_clean = Util.diff_split(old_nds, old_clean, cur_nds, cur_clean)
      @clean_geom = [cur_nds, new_clean].transpose
      # check the clean-ness. if the new nodes are all clean, then this version
      # may also be fully clean.
      is_fully_clean = is_fully_clean && @clean_geom.all? {|n,c| c}
    when OSM::Relation
      old_mem, old_clean = @clean_geom.empty? ? [[],[]] : @clean_geom.transpose
      cur_mem, cur_clean = obj.members, obj.members.map { true }
      new_clean = Util.diff_split(old_mem, old_clean, cur_mem, cur_clean)
      @clean_geom = [cur_mem, new_clean].transpose
      is_fully_clean = is_fully_clean && @clean_geom.all {|m,c| c}
    end
    @cleans << is_fully_clean
    @acceptors << true
    @clean_values.merge!(clean_tags)
  end

  def merge_dirty(obj)
    geom_is_diff = case obj
                     when OSM::Node
                     @clean_geom != obj.geom
                     when OSM::Way
                     (@clean_geom.map {|n,c| n}) != obj.geom
                     when OSM::Relation
                     (@clean_geom.map {|m,c| m}) != obj.geom
                   end
    if Tags.significant?(@clean_values, obj.tags) or geom_is_diff
      @cleans << false
      @acceptors << false
      # tags which were created in this version of the object are
      # now tainted :-(
      @tainted_tags.merge!(obj.tags.select {|k,v| not @clean_values.has_key?(k)})
      # tags which were modified from the previous clean version 
      # are also tainted as long as the change is significant :'(
      keys_in_both = obj.tags.keys & @clean_values.keys
      changed_keys = keys_in_both.select {|k| Tags.significant_tag?(@clean_values[k], obj.tags[k])}
      @tainted_tags.merge!(obj.tags.select {|k,v| changed_keys.include? k})
      # tags removed in the dirty version can be kept as deleted
      # though.
      (@clean_values.keys - obj.tags.keys).each {|k| @clean_values.delete(k)}
      case obj
      when OSM::Node
        # can't use dirty geometry

      when OSM::Way
        if (@clean_geom.map {|n,c| n}) != obj.geom
          old_nds, old_clean = @clean_geom.empty? ? [[],[]] : @clean_geom.transpose
          cur_nds, cur_clean = obj.nodes, obj.nodes.map { false }
          new_clean = Util.diff_split(old_nds, old_clean, cur_nds, cur_clean)
          @clean_geom = [cur_nds, new_clean].transpose
        end

      when OSM::Relation
        if (@clean_geom.map {|m,c| m}) != obj.geom
          old_mem, old_clean = @clean_geom.empty? ? [[],[]] : @clean_geom.transpose
          cur_mem, cur_clean = obj.members, obj.members.map { false }
          new_clean = Util.diff_split(old_mem, old_clean, cur_mem, cur_clean)
          @clean_geom = [cur_mem, new_clean].transpose
        end
      end
    else
      # if we get here then the tag changes weren't significant and
      # the geometry was the same.
      if is_clean?
        merge_clean_onto_clean(obj)
      else
        merge_clean_onto_dirty(obj)
      end
    end
  end

  def is_clean?
    @cleans.all?
  end

  def actions
    first_act = nil
    acts = Array.new
    clean_flag = true
    prev_obj = nil
    max_version = nil
    clean_history = Array.new
    unredacts_later = Array.new

    @versions.zip(@cleans).zip(@acceptors).map {|i| i.flatten}.each do |obj,clean,acceptor| 
      clean_flag = clean_flag && clean
      clean_history << clean_flag

      unless clean_flag
        done = false
        odbl_clean = Tags.odbl_clean?(obj.tags)

        if (clean or acceptor) and 
            ((prev_obj.nil? or obj.geom != prev_obj.geom) or
             (odbl_clean))
          case obj
          when OSM::Node
            if obj.tags.empty? or odbl_clean
              act = :untagged
            else
              act = :clean
              new_obj = obj.clone
            end
          when OSM::Way
            if odbl_clean or ((obj.tags == @clean_values) && ((@clean_geom.select {|n,c| c}.map {|n,c| n}) == obj.nodes))
              act = :untagged
            else
              act = :clean
              new_obj = obj.clone
              new_obj.nodes = @clean_geom.select {|n,c| c}.map {|n,c| n}
            end
          when OSM::Relation
            if odbl_clean or ((obj.tags == @clean_values) && ((@clean_geom.select {|m,c| c}.map {|m,c| m}) == obj.members))
              act = :untagged
            else
              act = :clean
              new_obj = obj.clone
              new_obj.members = @clean_geom.select {|m,c| c}.map {|m,c| m}
            end
          end

          if act == :untagged
            first_act = nil
            clean_flag = true
            done = true
          elsif act == :clean
            @clean_values.delete_if {|k,v| @tainted_tags.has_key? k}
            new_obj.tags = @clean_values
            first_act = Edit[new_obj]
            acts << Redact[obj.class, obj.element_id, obj.version, acceptor ? :visible : :hidden]
            unredacts_later << obj.version if clean
            clean_flag = true
            done = true
          end
        end

        if clean and not clean_flag
          # if it exactly matches a previous clean version then it's
          # a revert and is clean.
          reverts = @versions.zip(clean_history).select {|hobj, ch| (obj.tags == hobj.tags) and (obj.geom == hobj.geom) and ch}
          unless reverts.empty?
            clean_flag = true
            first_act = nil
            done = true
          end
        end

        if not done
          if first_act.nil?
            if prev_obj.nil?
              first_act = Delete[obj.class, obj.element_id]
            else
              first_act = Edit[prev_obj]
            end
          end
          
          acts << Redact[obj.class, obj.element_id, obj.version, acceptor ? :visible : :hidden]
        end
      end
      prev_obj = obj
      max_version = obj.version
    end
    # need to adjust any edit actions to represent changes from 
    # the last version of the object we've seen.
    if (not first_act.nil?) and (first_act.class == Edit)
      acts.delete_if {|o| (o.version != max_version) and unredacts_later.include?(o.version) }
      unredacts_later = Array.new
      first_act = first_act.clone
      first_act.obj.changeset_id = -1
      first_act.obj.version = max_version
      first_act.obj.tags = @clean_values
    end
    first_act.nil? ? acts : [first_act] + acts
  end
end

class ChangeBot
  def initialize(db)
    @db = db
    @pending_deletes = Array.new
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
    h.each_version do |element|
      if changeset_is_accepted?(element.changeset_id)
        if h.is_clean?
          h.merge_clean_onto_clean(element)
        else
          h.merge_clean_onto_dirty(element)
        end
      else
        h.merge_dirty(element)
      end
    end
    h.actions
  end

  def changeset_is_accepted?(changeset_id)
    cs = @db.changeset(changeset_id)
    accepted = cs.user.accepted_cts? 
    accepted = accepted or (not cs.user.adopter.nil? and cs.user.adopter.accepted_cts?)
    accepted = accepted or cs.override_accepted?
    return accepted
  end
end
