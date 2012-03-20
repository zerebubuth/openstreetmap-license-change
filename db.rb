require './osm'

class DB
  def initialize(changesets)
    @changesets = changesets
    @exclusions = Hash.new
  end

  def exclude(klass, ids)
    unless @exclusions.has_key? klass
      @exclusions[klass] = Set.new
    end

    ids.each { |i| @exclusions[klass].add(i) }
  end

  def exclude?(klass, i)
    @exclusions.has_key?(klass) && @exclusions[klass].include?(i)
  end

  def changeset(cs_id)
    @changesets[cs_id]
  end
end
