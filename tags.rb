require 'text'
require './abbreviations'

##
# module for various functions to do with tags.
#
module Tags
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
      if k.downcase == "odbl" 
        val = tags[k].downcase
        # tag synonyms for "clean" in this context
        (val == "clean" ||
         val == "true"  ||
         val == "yes"   ||
         val == "1")
      else
        false
      end
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
    changes_are_significant = changed_keys.map {|k| Tags.significant_tag?(old[k], new[k])}.any?
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
    # normalise all punctuation to single spaces
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
    return false if Text::Metaphone.metaphone(old) == Text::Metaphone.metaphone(new)

    # finally, look for changes in abbreviation.
    return false if Abbrev.equal_expansions(old, new)

    # otherwise, just look at the strings...
    old != new
  end
end
