require './osm'
require './util'
require './diff'

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

    def to_s
      @null_move ? "NodeDiff[]" : "NodeDiff#{@position.inspect}"
    end

    private
    def initialize(null_move, position)
      @null_move, @position = null_move, position
    end
  end

  class WayDiff
    def self.create(a, b)
      WayDiff.new(Diff::diff(a.nodes, b.nodes))
    end

    def empty?
      @diff.empty?
    end

    def only_deletes?
      @diff.all? {|act| act.class == Diff::Delete}
    end

    def apply(geom, options = {})
      options[:state] = Array.new unless options.has_key?(:state)
      new_state, comp_diff = Diff::compose(options[:state], @diff)
      options[:state].replace(new_state)

      if options[:only] == :deleted
        delete, other = Diff::split_deletes(comp_diff)
        options[:state][0...0] = other
        Diff::apply(delete, geom)

      else
        Diff::apply(comp_diff, geom)
      end
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
      RelationDiff.new(Diff::diff(a.members, b.members, 
                                  :detect_alter => 
                                    (Proc.new {|a, b| (a.type == b.type) && (a.ref == b.ref)}),
                                  :detect_move => true))
    end

    def empty?
      @diff.empty?
    end

    def only_deletes?
      @diff.all? {|act| act.class == Diff::Delete}
    end

    def apply(geom, options = {})
      options[:state] = Array.new unless options.has_key?(:state)
      new_state, comp_diff = Diff::compose(options[:state], @diff)
      options[:state].replace(new_state)

      if options[:only] == :deleted
        delete, other = Diff::split_deletes(comp_diff)
        options[:state][0...0] = other
        Diff::apply(delete, geom)

      else
        Diff::apply(comp_diff, geom)
      end
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
