require './osm'
require './db'
require './actions'
require 'set'

class History
  def initialize(versions)
    # todo: ensure sort
    @versions = versions
    @tainted_keys = Set.new
    @clean_values = Hash.new
    @cleans = Array.new
  end

  def each_version
    @versions.each do |v|
      yield v
    end
  end

  def merge_clean_onto_clean(obj)
    @cleans << true
    @clean_values = obj.tags
  end

  def merge_clean_onto_dirty(obj)
    @cleans << true
    # merge any value changes for non-tainted keys into the 
    # tag set.
    clean_tags = obj.tags.select {|k, v| not @tainted_keys.include? k}
    @clean_values.merge!(clean_tags)
  end

  def merge_dirty(obj)
    @cleans << false
    # tags which were created in this version of the object are
    # now tainted :-(
    @tainted_keys.merge(obj.tags.keys - @clean_values.keys)
    # tags which were modified from the previous clean version 
    # are also tainted :'(
    keys_in_both = obj.tags.keys & @clean_values.keys
    changed_keys = keys_in_both.select {|k| obj.tags[k] != @clean_values[k]}
    @tainted_keys.merge(changed_keys)
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
    @versions.zip(@cleans).each do |obj,clean| 
      clean_flag = clean_flag && clean
      unless clean_flag
        if clean and 
            obj.class == OSM::Node and 
            (prev_obj.nil? or obj.position != prev_obj.position)
          if obj.tags.empty?
            first_act = nil
          else
            @tainted_keys.merge(prev_obj.tags.keys)
            @clean_values.delete_if {|k,v| @tainted_keys.include? k}
            new_obj = obj.clone
            new_obj.tags = @clean_values
            first_act = Edit[new_obj]
            acts << Redact[obj.class, obj.element_id, obj.version, clean ? :visible : :hidden]
          end
          clean_flag = true
        else

          if first_act.nil?
            if prev_obj.nil?
              first_act = Delete[obj.class, obj.element_id]
            else
              first_act = Edit[prev_obj]
            end
          end
          
          acts << Redact[obj.class, obj.element_id, obj.version, clean ? :visible : :hidden]
        end
      end
      prev_obj = obj
      max_version = obj.version
    end
    # need to adjust any edit actions to represent changes from 
    # the last version of the object we've seen.
    if (not first_act.nil?) and (first_act.class == Edit)
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
