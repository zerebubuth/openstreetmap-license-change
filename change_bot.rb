require './osm'
require './db'
require './actions'

class History
  def initialize(versions)
    # todo: ensure sort
    @versions = versions
    @tainted_keys = Array.new
    @tainted_values = Hash.new
    @cleans = Array.new
  end

  def each_version
    @versions.each do |v|
      yield v
    end
  end

  def merge_clean_onto_clean(obj)
    @cleans << true
  end

  def merge_clean_onto_dirty(obj)
    @cleans << true
  end

  def merge_dirty_onto_clean(obj)
    @cleans << false
  end

  def merge_dirty_onto_dirty(obj)
    @cleans << false
  end

  def is_clean?
    @cleans.all?
  end

  def actions
    acts = Array.new
    clean_flag = true
    prev_obj = nil
    max_version = nil
    @versions.zip(@cleans).each do |obj,clean| 
      clean_flag = clean_flag && clean
      unless clean_flag
        if acts.empty?
          if prev_obj.nil?
            acts << Delete[obj.class, obj.element_id]
          else
            acts << Edit[prev_obj]
          end
        end
        acts << Redact[obj.class, obj.element_id, obj.version, clean ? :visible : :hidden]
      end
      prev_obj = obj
      max_version = obj.version
    end
    # need to adjust any edit actions to represent changes from 
    # the last version of the object we've seen.
    if (not acts.empty?) and (acts[0].class == Edit)
      acts[0] = acts[0].clone
      acts[0].obj.changeset_id = -1
      acts[0].obj.version = max_version
    end
    acts
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
        if h.is_clean?
          h.merge_dirty_onto_clean(element)
        else
          h.merge_dirty_onto_dirty(element)
        end
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
