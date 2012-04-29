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
      @diff.empty?
    end

    def only_deletes?
      @diff.all? {|op, idx, elt| op == :delete}
    end

    def apply(geom, options = {})
      geom_idx = 0
      new_geom = geom.clone
      # mapping instruction index (i.e: in old geom) to
      # current index in new_geom.
      mapping = Hash[(0...(new_geom.length)).map {|i| [i,i]}]
      
      only_delete = options[:only] == :deleted

      @diff.each do |op, idx, elt|
        case op
        when :delete
          new_idx = mapping[idx]
          # note: we ignore the role as far as comparing before
          # applying the patch is concerned - it'll still delete
          # the same element...
          unless (new_idx.nil? || 
                  new_geom[new_idx].nil? ||
                  new_geom[new_idx].type != elt.type ||
                  new_geom[new_idx].ref != elt.ref)
            new_geom.delete_at(new_idx)
            mapping.delete(idx)
            mapping.each {|k,v| mapping[k] = v - 1 if v > new_idx}
            #puts "delete: #{elt}@#{idx}[#{new_idx}] -> #{mapping}"
          end

        when :insert
          unless only_delete
            new_idx = mapping[idx]
            new_idx = 0 if new_idx.nil? && mapping.empty?
            new_idx = mapping.values.max + 1 if new_idx.nil?
            
            new_geom.insert(new_idx, elt)
            mapping.each {|k,v| mapping[k] = v + 1 if v >= new_idx}
            mapping[idx] = new_idx + 1 unless mapping.has_key? idx
            #puts "insert: #{elt}@#{idx}[#{new_idx}] -> #{mapping}"
          end

        when :move
          unless only_delete
            old_idx_from, old_idx_to = idx
            
            new_idx_to = mapping[old_idx_to]
            new_idx_from = mapping[old_idx_from]
            unless new_idx_from.nil? || new_geom[new_idx_from] != elt
              new_idx_to = 0 if new_idx_to.nil? && mapping.empty?
              new_idx_to = mapping.values.max + 1 if new_idx_to.nil?
              
              new_geom.insert(new_idx_to, elt)
              mapping.each {|k,v| mapping[k] = v + 1 if v >= new_idx_to}
              mapping[old_idx_to] = new_idx_to + 1 unless mapping.has_key? old_idx_to
              
              # reset new_index_from after mapping change
              new_idx_from = mapping[old_idx_from]
              new_geom.delete_at(new_idx_from)
              mapping.delete(old_idx_from)
              mapping.each {|k,v| mapping[k] = v - 1 if v > new_idx_from}
            end
          end
          
        when :alter
          unless only_delete
            new_idx = mapping[idx]
            # don't bother comparing the old value of the role,
            # since that's what we're overwriting anyway.
            unless (new_idx.nil? || 
                    new_geom[new_idx].nil? ||
                    new_geom[new_idx].type != elt[1].type ||
                    new_geom[new_idx].ref != elt[1].ref)
              new_geom[new_idx] = elt[1]
            end
          end
        end
      end

      return new_geom
    end
    
    def to_s
      "RelationDiff[" + @diff.inspect + "]"
    end

    private
    def initialize(d)
      a_idx = 0
      @diff = Array.new

      d.each do |src, elt|
        case src
        when :a # element only in A: a delete
          @diff << [:delete, a_idx, elt]
          a_idx += 1

        when :b # element only in B: an insert
          @diff << [:insert, a_idx, elt]
          
        when :c # element in both - ignore
          a_idx += 1
        end
      end

      # try and find insert-delete pairs where the
      # element is exactly the same. these are the
      # moves.
      moves = @diff.
        group_by {|op,idx,elt| elt}.
        select {|elt,vec| (vec.length > 1 && 
                           vec.any? {|op,idx,el| op == :insert} && 
                           vec.any? {|op,idx,el| op == :delete})}

      moves.each do |elt, vec|
        # could be more than 2 - for simplicity 
        # just assume the first of each delete 
        # and insert.
        from = vec.find {|op,idx,elt| op == :delete}
        to   = vec.find {|op,idx,elt| op == :insert}

        from_idx = @diff.find_index(from)
        to_idx   = @diff.find_index(to)

        #puts "from_idx:#{from_idx} to_idx:#{to_idx}"
        @diff[from_idx] = [:move, [from[1], to[1]], elt]
        @diff.delete_at(to_idx)
      end

      # now try and detect alterations to the role
      # which we treat separately from other changes.
      alters = @diff.
        select {|op,idx,elt| op != :move}.
        group_by {|op,idx,elt| [(op == :insert) ? idx - 1 : idx, elt.type, elt.ref]}.
        select {|x,vec| (vec.length > 1 && 
                           vec.any? {|op,idx,el| op == :insert} && 
                           vec.any? {|op,idx,el| op == :delete})}

      alters.each do |x, vec|
        # could be more than 2 - for simplicity 
        # just assume the first of each delete 
        # and insert.
        from = vec.find {|op,idx,elt| op == :delete}
        to   = vec.find {|op,idx,elt| op == :insert}

        from_idx = @diff.find_index(from)
        to_idx   = @diff.find_index(to)

        #puts "from_idx:#{from_idx} to_idx:#{to_idx}"
        @diff[from_idx] = [:alter, from[1], [from[2], to[2]]]
        @diff.delete_at(to_idx)        
      end
    end
  end
end
