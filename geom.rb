require './osm'

module Geom
  def self.diff(a, b)
    case a
    when OSM::Node
      NodeDiff.create(a, b)
    when OSM::Way
      WayDiff.create(a, b)
    when OSM::Relation
      RelationDiff.create(a, b)
    end
  end

  class NodeDiff
    def self.create(a, b)
      NodeDiff.new(a.position == b.position, b.position)
    end

    def empty?
      @null_move
    end

    def apply(geom, options = {})
      if empty? or options[:only] == :deleted
        geom
      else
        @position
      end
    end

    def apply!(obj, options = {})
      obj.position = apply(obj.position, options) unless @null_move
    end

    private
    def initialize(null_move, position)
      @null_move, @position = null_move, position
    end
  end

  class WayDiff
  end

  class RelationDiff
  end
end
