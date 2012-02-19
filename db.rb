require './osm'

class DB
  def initialize(changesets)
    @changesets = changesets
  end

  def changeset(cs_id)
    @changesets[cs_id]
  end
end
