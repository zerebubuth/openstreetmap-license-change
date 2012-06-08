# -*- coding: utf-8 -*-
require 'text'
require './abbreviations'

##
# module for various functions to do with tags.
#
module Tags
  # keys which have automatic values, and deletions of 
  # these aren't considered to be significant.
  AUTO_KEYS = [ 'created_by' ]

  # tests whether a set of tags is signifying an object as
  # having been manually checked and accepted as clean for
  # the purposes of ODbL compliance. 
  #
  # since this is a manually-added tag then we take it at
  # face value and do no further checking. however, also
  # because it is manually-added, we must check for various
  # synonyms (and misspellings?)
  def self.odbl_clean?(tags)
    tags.keys.any? do |k| 
      # special case for this one misspelling, as it's fairly
      # common to find "obdl" and there's no chance that we're
      # confusing "obdl" with anything else.
      if (k.downcase == "odbl" or 
          k.downcase == "obdl" or
          k.downcase == "oodbl")
        val = tags[k].downcase
        # tag synonyms for "clean" in this context
        (val == "clean" ||
         val == "clear"  ||
         val == "true"  ||
         val == "yes"   ||
         val == "clear" ||
         val == "1")
      else
        false
      end
    end
  end    

  def self.diff(a, b)
    Diff.create(a.tags, b.tags)
  end

  #
  #
  class Diff
    attr_accessor :unchanged, :created, :deleted, :edited, :moved

    def self.create(a, b)
      # unchanged tags - where the key and the value both appear
      # exactly the same in both versions.
      unchanged = Hash[a.select {|k, v| b[k] == v}]

      # initial estimate of created and deleted entries are just
      # those which aren't in the unchanged set.
      created = b.select {|k,v| not unchanged.has_key? k}
      deleted = a.select {|k,v| not unchanged.has_key? k}

      # take out updates to things with "automatic" keys. these
      # are things that get changed by bots and can be safely
      # assumed always clean.
      auto_key_changes = Hash.new
      AUTO_KEYS.each do |k|
        if created.has_key? k
          auto_key_changes[k] = created[k]
          created.delete k
        end
      end
      
      # now look for things being created and deleted with the
      # same key, these things have had their value edited
      common_keys = created.keys & deleted.keys
      edited = Hash[common_keys.map do |k|
                      # move old & new values out of created &
                      # deleted hashes.
                      old_val = deleted[k]; deleted.delete k
                      new_val = created[k]; created.delete k
                      # and return a move record for them.
                      [k, [old_val, new_val]]
                    end]
      
      # there's another kind of move, where the key is altered
      # so look for that now.
      moved = Hash[created.
                   select {|k,v| deleted.has_value? v}.
                   map {|k,v| dk = deleted.select {|k2,v2| v == v2}.first.first; [[dk, k], v]
                   }]
      moved.each do |keys,v| 
        deleted.delete keys[0]
        created.delete keys[1]
      end

      # extract out the trivial changes, as these are treated
      # very differently by the algorithm.
      edited, trivial_edited = edited.
        partition {|k, vals| Tags.significant_tag?(*vals)}.
        map {|a| Hash[a]}

      moved, trivial_moved = moved.
        partition {|keys, v| Tags.significant_tag?(*keys)}.
        map {|a| Hash[a]}

      return Diff.new(unchanged, created, deleted, edited, moved, 
                      auto_key_changes, trivial_edited, trivial_moved)
    end

    def apply(original, options = {})
      tags = original.clone
      omit_tags = (options.has_key? :omit_tags) ? options[:omit_tags] : {}
      @deleted.each_key {|k| tags.delete k}

      if options[:only] == :deleted then
        omit_tags.each{|k, v| tags[k] = v if @created[k] == v} if not @created.nil?
      else
        tags.merge!(@created)

        @edited.each do |k, vals|
          old_val, new_val = vals
          tags[k] = new_val
        end
        
        @moved.each do |keys, v|
          old_key, new_key = keys
          tags.delete old_key
          tags[new_key] = v
        end
      end

      @trivial_edited.each do |k, vals|
        old_val, new_val = vals
        tags[k] = new_val if tags[k] == old_val
      end

      @trivial_moved.each do |keys, v|
        old_key, new_key = keys
        if tags[old_key] == v
          tags.delete old_key
          tags[new_key] = v
        end
      end

      tags.merge!(@auto_key_changes)
      return tags
    end

    def apply!(obj, options = {})
      obj.tags = apply(obj.tags, options)
    end

    def reverse
      # TODO: auto key changes doesn't reverse properly
      Diff.new(@unchanged, @deleted, @created,
               Hash[@edited.map {|k, vals| [k, vals.reverse]}],
               Hash[@moved.map {|keys, v| [keys.reverse, v]}],
               {},
               Hash[@trivial_edited.map {|k, vals| [k, vals.reverse]}],
               Hash[@trivial_moved.map {|keys, v| [keys.reverse, v]}])
    end

    def empty?
      [@created, @deleted, @edited, @moved, @trivial_edited, @trivial_moved].all? {|x| x.empty?}
    end
    
    def only_deletes?
      [@created, @edited, @moved, @trivial_edited, @trivial_moved].all? {|x| x.empty?}
    end

    def trivial?
      [@created, @deleted, @edited, @moved].all? {|x| x.empty?}
    end
    
    def to_s
      members = [:@unchanged, :@created, :@deleted, :@edited, :@moved, 
                 :@auto_key_changes, :@trivial_edited, :@trivial_moved]
      "TagDiff[" + (members.
                    map {|x| [x, instance_variable_get(x)]}.
                    select {|x,m| not m.empty? }.
                    map {|x,m| "#{x}=>#{m}"}.
                    join(",")
                    ) + "]"
    end

    private

    def initialize(unchanged, created, deleted, edited, moved, 
                   auto_key_changes, trivial_edited, trivial_moved)
      @unchanged, @created, @deleted, @edited, @moved =
        unchanged, created, deleted, edited, moved
      @auto_key_changes, @trivial_edited, @trivial_moved = 
        auto_key_changes, trivial_edited, trivial_moved
    end
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
    changes_are_significant = changed_keys.map do |k| 
      (not AUTO_KEYS.include?(k)) && Tags.significant_tag?(old[k], new[k])
    end.any?
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
    # any creations at all are considered significant.
    return true unless created_keys.empty?

    # deletions are never considered significant, by the
    # rules of 'deletions are OK', so ignore the deleted
    # keys.

    # the remaining question is then if any of the key
    # moves are significant.
    moves_are_significant = moved_keys.keys.map {|o, n| Tags.significant_tag?(o, n)}.any?
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
    # special case: apostrophes normalise to nothing, rather than
    # a space.
    old.gsub!(/[＇'ʼʹ]/, "")
    new.gsub!(/[＇'ʼʹ]/, "")
    # handle german double s
    old.gsub!(/[ß]/, "ss")
    new.gsub!(/[ß]/, "ss")
    # normalise all punctuation to single spaces
    # TODO: Should we treat semicolon as a splitter and do array comparison?
    old.gsub!(/[[:punct:][:space:]]+/," ")
    new.gsub!(/[[:punct:][:space:]]+/," ")
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
    begin
      mp_old = Text::Metaphone.metaphone(old)
      mp_new = Text::Metaphone.metaphone(new)
      return false if mp_old.gsub(/ /,"").length > 0 and mp_old == mp_new 
    end

    # look for changes in abbreviation.
    return false if Abbrev.equal_expansions(old, new)

    # check if the strings are the same except for whitespace
    # presence. this would be considered insignificant.
    return false if old.gsub(/ /,"") == new.gsub(/ /,"")
              
    # To handle road numbers where only difference is presence or otherwise of
    # alphabetic prefix. Remove all alpha prefixes from numbers where present
    # and test again. (Only handles single letter prefix, allow more?)
    return false if old.gsub(/\w(\d)/, '\1') == new.gsub(/\w(\d)/, '\1')

    # otherwise, just look at the strings...
    old != new
  end
end
