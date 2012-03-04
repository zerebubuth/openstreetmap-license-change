require 'rubygems'
require './osm'
require './db'
require './actions'
require 'set'
require 'text'

class History
  def initialize(versions)
    # todo: ensure sort
    @versions = versions
    @tainted_keys = Set.new
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
    @clean_geom = obj.geom
  end

  def merge_clean_onto_dirty(obj)
    # merge any value changes for non-tainted keys into the 
    # tag set.
    is_fully_clean = true
    clean_tags = obj.tags.select do |k, v| 
      any_tainted = @tainted_keys.include?(k)
      if any_tainted
        is_fully_clean = false
      end
      not any_tainted
    end
    @cleans << is_fully_clean
    @acceptors << true
    @clean_values.merge!(clean_tags)
  end

  def merge_dirty(obj)
    if History.significant?(@clean_values, obj.tags) or @clean_geom != obj.geom
      @cleans << false
      @acceptors << false
      # tags which were created in this version of the object are
      # now tainted :-(
      @tainted_keys.merge(obj.tags.keys - @clean_values.keys)
      # tags which were modified from the previous clean version 
      # are also tainted :'(
      keys_in_both = obj.tags.keys & @clean_values.keys
      changed_keys = keys_in_both.select {|k| obj.tags[k] != @clean_values[k]}
      @tainted_keys.merge(changed_keys)
      # tags removed in the dirty version can be kept as deleted
      # though.
      (@clean_values.keys - obj.tags.keys).each {|k| @clean_values.delete(k)}
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

        if (clean or acceptor) and 
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
            acts << Redact[obj.class, obj.element_id, obj.version, acceptor ? :visible : :hidden]
            unredacts_later << obj.version
          end
          clean_flag = true
          done = true
        end

        if clean and not clean_flag
          # if it exactly matches a previous clean version then it's
          # a revert and is clean.
          reverts = @versions.zip(clean_history).select {|hobj, ch| (obj.tags == hobj.tags) and (obj.position == hobj.position) and ch}
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

  # tests whether the change of tags from +old+ to +new+ is
  # significant. that is, deserving of some form of legal 
  # protection. 
  #
  # the grounds for this is whether the change is trivial or
  # not. considerations for this include; whether the change
  # could have been made automatically, whether it could be 
  # a simple correction, etc...
  def self.significant?(old, new)
    # simply, if they're the same, then it there is no
    # change to be significant.
    return false if old == new

    # remove all the k-v pairs which are the same, so we're
    # only looking at differences.
    new_keys = Set.new(new.keys)
    old_keys = Set.new(old.keys)

    # common and changed keys from the intersection of the
    # two key sets
    common_keys, changed_keys = new_keys.intersection(old_keys).partition {|k| old[k] == new[k]}

    # if any of the changed keys are significant then this
    # edit will be significant.
    changes_are_significant = changed_keys.map {|k| History.significant_tag?(old[k], new[k])}.any?
    return true if changes_are_significant

    # the differences of the key sets give us created and
    # deletes keys.
    created_keys = new_keys - old_keys
    deleted_keys = old_keys - new_keys

    # now look at created key values which are the same as
    # deleted key values - this will be a moved value.
    new_values = created_keys.inject(Hash.new) {|h,k| h[new[k]] = k; h}
    old_values = deleted_keys.inject(Hash.new) {|h,k| h[old[k]] = k; h}
    moved_keys = Hash.new
    Set.new(new_values.keys).intersection(Set.new(old_values.keys)).each do |v|
      new_key = new_values[v]
      old_key = old_values[v]
      moved_keys[[new_key, old_key]] = v
      created_keys.delete(new_key)
      deleted_keys.delete(old_key)
    end
    # we don't count deletions as significant(?), but any 
    # creations at all are considered significant.
    return true unless created_keys.empty?
    return true unless deleted_keys.empty?

    # the remaining question is then if any of the key
    # moves are significant.
    moves_are_significant = moved_keys.keys.map {|o, n| History.significant_tag?(o, n)}.any?
    return moves_are_significant
  end

  # this is basically checking whether two strings are
  # very close. things which might not be considered a
  # significant edit:
  #  - correction of spelling or punctuation
  #  - change of punctuation (where 'correct' is a 
  #    matter of opinion)
  #  - abbreviation, or expansion of
  #  - changes in case or whitespace
  def self.significant_tag?(old_v, new_v)
    # if they only differ by case, then it isn't significant, so
    # do the remaining tests all in downcase.
    old = old_v.downcase
    new = new_v.downcase
    # if there's no downcase difference, return early.
    return false if old == new

    # otherwise, we first move to the levenshtein difference to
    # try and detect transpositions and misspellings.
    lev_dist = Text::Levenshtein.distance(old, new)
    if lev_dist < 3 and old.chars.sort == new.chars.sort
      # all the letters are the same, just in the wrong order,
      # so this isn't significant - likely a tpyo
      return false
    elsif lev_dist < ([old.length, new.length].min / 8)
      # if the levenshtein difference is only a small proportion
      # of the size of the string, then it's likely either a tpyo 
      # or a misspeling two!
      return false
    end
    
    # now check for homophones (TODO: is this really appropriate?)
    return false if Text::Metaphone.metaphone(old) == Text::Metaphone.metaphone(new)

    # now, remove all punctuation and see what's left
    return false if old.gsub(/[[:punct:][:space:]]/,"") == new.gsub(/[[:punct:][:space:]]/,"")

    # otherwise, just look at the strings...
    old != new
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
