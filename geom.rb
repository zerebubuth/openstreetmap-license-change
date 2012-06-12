require './osm'
require './util'
require './diff'

module Geom
  def self.close?(a, b)
    return false if a.nil? or b.nil?
    delta = 0.0000002
    x = a[0]-b[0]
    y = a[1]-b[1]
    x*x+y*y < delta*delta
  end

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
      NodeDiff.new(Geom::close?(a.position, b.position), b.position)
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
      WayDiff.new(Diff::diff(a.nodes, b.nodes, :detect_move => true))
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
      RelationDiff.new(a, b)
    end

    def empty?
      @old == @new
    end

    def only_deletes?
      @old.size > @new.size and diff.all? {|act| act.class == Diff::Delete}
    end

    def apply(geom, options = {})
      options[:state] = Array.new unless options.has_key?(:state)
      only_delete = options[:only] == :deleted
      no_order = options[:no_order] == true
      
      #if only_delete and (@new.empty? or geom.empty?)
      #    return []
      #end
      
      if geom == @old and not only_delete then
        options.delete(:state)
        return @new
      end
      
      if no_order then
        if only_delete then
          return geom - @old.select{|e| @new.count{|n| e.type == n.type and e.ref == n.ref} == 0}
        end
        #deletes
        geom.delete_if{|e| @new.count{|n| e.type == n.type and e.ref == n.ref} == 0}
        #adds
        geom += @new.select{|e| @old.count{|n| e.type == n.type and e.ref == n.ref} == 0}
        #alter
        @old.select{|e| @new.count{|n| e.type == n.type and e.ref == n.ref} > 0}.each do |e|
          if not geom.delete(e).nil? then
            geom += @new.select{|n| e.type == n.type and e.ref == n.ref}
          end
        end
        return geom
      end

      new_state, comp_diff = Diff::compose(options[:state], diff)
      options[:state].replace(new_state)

      if only_delete then
        delete, other = Diff::split_deletes(comp_diff)
        options[:state][0...0] = other
        Diff::apply(delete, geom)
      else
        Diff::apply(comp_diff, geom)
      end
    end
    
    def to_s
      "RelationDiff[" + diff.inspect + "]"
    end

    private
    
    def diff
      make_diff(@old, @new) if @diff.nil?
      @diff
    end
    
    def initialize(a, b)
    @old, @new = a.geom, b.geom
    end
    
    def make_diff(a, b)
      @diff = Diff::diff(a, b,
        :detect_alter => (Proc.new {|a, b| (a.type == b.type) && (a.ref == b.ref)}),
        :detect_move => true)
      end
  end
end
