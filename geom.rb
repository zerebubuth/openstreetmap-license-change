require './osm'
require './util'

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

    def only_deletes?
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

    def to_s
      "NodeDiff[#{@null_move},#{@position}]"
    end

    private
    def initialize(null_move, position)
      @null_move, @position = null_move, position
    end
  end

  class WayDiff
    def self.create(a, b)
      WayDiff.new(Util.diff(a.nodes, b.nodes))
    end

    def empty?
      @diff.all? {|source, elt| source == :c}
    end

    def only_deletes?
      not @diff.any? {|source, elt| source == :b}
    end

    def apply(geom, options = {})
      geom_idx = 0
      new_geom = Array.new

      @diff.each do |source, elt|
        case source
        when :a # exists only in previous - i.e: a delete
          if geom[geom_idx] == elt
            geom_idx += 1
          end

        when :b # exists only in new version - i.e: an add
          new_geom << elt unless options[:only] == :deleted

        when :c # exists in both - i.e: unchanged
          if geom[geom_idx] == elt
            new_geom << elt
            geom_idx += 1
          end
        end
      end

      return new_geom
    end
    
    def apply!(obj, options = {})
      obj.nodes = apply(obj.nodes, options)
    end

    def to_s
      "WayDiff[" + @diff.inspect + "]"
    end

    private
    def initialize(d)
      @diff = d
    end
  end

  class RelationDiff
    def self.create(a, b)
      RelationDiff.new(Util.diff(a.members, b.members))
    end

    def empty?
      @diff.all? {|source, elt| source == :c}
    end

    def only_deletes?
      not @diff.any? {|source, elt| source == :b}
    end

    def apply(geom, options = {})
      geom_idx = 0
      new_geom = Array.new

      @diff.each do |source, elt|
        case source
        when :a # exists only in previous - i.e: a delete
          if geom[geom_idx] == elt
            geom_idx += 1
          end

        when :b # exists only in new version - i.e: an add
          new_geom << elt unless options[:only] == :deleted

        when :c # exists in both - i.e: unchanged
          if geom[geom_idx] == elt
            new_geom << elt
            geom_idx += 1
          end
        end
      end

      return new_geom
    end
    
    def apply!(obj, options = {})
      obj.members = apply(obj.members, options)
    end

    def to_s
      "RelationDiff[" + @diff.inspect + "]"
    end

    private
    def initialize(d)
      @diff = d
    end
  end
end
