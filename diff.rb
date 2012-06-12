require './util'

module Diff
  Insert = Struct.new(:location, :element) do 
    def apply(array)
      raise "Index mismatch on insert: #{self.location} not between 0 and #{array.length}." if self.location < 0 or self.location > array.length
      rv = array.clone
      rv.insert(self.location, self.element)
      return rv
    end

    def to_s
      "Insert[#{self.location},#{self.element}]"
    end

    def inspect
      to_s
    end

    def move(off)
      Insert.new(self.location + off, self.element)
    end
  end

  Delete = Struct.new(:location, :element) do
    def apply(array)
      raise "Index mismatch on delete: #{self.location} not between 0 and #{array.length-1}." if self.location < 0 or self.location >= array.length
      raise "Element mismatch on delete: element at location (#{self.location}) #{array[self.location]} != expected #{self.element}." if array[self.location] != self.element
      rv = array.clone
      rv.delete_at(self.location)
      return rv
    end

    def to_s
      "Delete[#{self.location},#{self.element}]"
    end

    def inspect
      to_s
    end

    def move(off)
      Delete.new(self.location + off, self.element)
    end
  end

  Alter = Struct.new(:location, :from_elt, :to_elt) do
    def apply(array)
      raise "Index mismatch on alter: #{self.location} not between 0 and #{array.length-1}." if self.location < 0 or self.location >= array.length
      raise "Element mismatch on alter: element at location (#{self.location}) #{array[self.location]} != expected #{self.from_elt}." if array[self.location] != self.from_elt
      rv = array.clone
      rv[self.location] = self.to_elt
      return rv
    end

    def to_s
      "Alter[#{self.location},#{self.from_elt}->#{self.to_elt}]"
    end

    def inspect
      to_s
    end

    def move(off)
      Alter.new(self.location + off, self.from_elt, self.to_elt)
    end
  end

  Move = Struct.new(:from_loc, :to_loc, :element) do
    def apply(array)
      del = Delete.new(self.from_loc, self.element)
      ins = Insert.new(self.to_loc, self.element)

      begin
        ins.apply(del.apply(array))
      
      rescue Exception => ex
        raise "While processing #{self.to_s}: #{ex}"
      end
    end

    def to_s
      "Move[#{self.from_loc}->#{self.to_loc},#{self.element}]"
    end

    def inspect
      to_s
    end

    def move(off)
      Move.new(self.from_loc + off, self.to_loc + off, self.element)
    end

    # don't want to create self-moves: these are null operations
    # and should be treated as such!
    def self.create(from_loc, to_loc, element)
      if from_loc == to_loc
        nil
      else
        Move.new(from_loc, to_loc, element)
      end
    end
  end

  class Swap
    def self.swap(a, b)
      a_name = a.class.name.downcase.gsub(/.*::/, "")
      b_name = b.class.name.downcase.gsub(/.*::/, "")
      method = "swap_#{a_name}_#{b_name}"
      self.send(method.to_sym, a, b)
    end

    def self.swap_insert_insert(a, b)
      if a.location < b.location
        [b.move(-1), a]
      else
        [b, a.move(1)]
      end
    end

    def self.swap_insert_alter(a, b)
      if a.location < b.location
        [b.move(-1), a]
      elsif a.location == b.location
        [nil, Insert.new(b.location, b.to_elt)]
      else
        [b, a]
      end
    end

    def self.swap_insert_delete(a, b)
      if a.location < b.location
        [b.move(-1), a]
      elsif a.location == b.location
        [nil, nil]
      else
        [b, a.move(-1)]
      end
    end

    def self.swap_insert_move(a, b)
      if a.location == b.from_loc
        # the insert is immediately moved, so will end up
        # as an insert in the moved-to location. note that
        # the insert must be second in this list so that
        # they are kept back if they are tainted operations.
        [nil, Insert.new(b.to_loc, a.element)]
      else
        dist = 0
        new_from_loc = b.from_loc
        new_to_loc = b.to_loc
        
        if a.location < b.from_loc
          new_from_loc -= 1
          dist += 1
        end
        
        if (a.location < b.to_loc) || ((a.location == b.to_loc) && (b.from_loc < b.to_loc))
          new_to_loc -= 1
          dist -= 1
        end

        [Move.create(new_from_loc, new_to_loc, b.element), a.move(dist)]
      end
    end

    def self.swap_alter_insert(a, b)
      if a.location < b.location
        [b, a]
      else
        [b, a.move(1)]
      end
    end

    def self.swap_alter_alter(a, b)
      if a.location != b.location
        [b, a]
      else
        [Alter.new(a.location, a.from_elt, b.to_elt), nil]
      end
    end

    def self.swap_alter_delete(a, b)
      if a.location < b.location
        [b, a]
      elsif a.location == b.location
        [Delete.new(a.location, a.from_elt), nil]
      else
        [b, a.move(-1)]
      end
    end

    def self.swap_alter_move(a, b)
      if b.from_loc == a.location
        [Move.create(b.from_loc, b.to_loc, a.from_elt), a.move(b.to_loc - b.from_loc)]

      else
        dist = 0
        dist -= 1 if a.location > b.from_loc
        dist += 1 if (a.location > b.to_loc) || ((a.location == b.to_loc) && (b.from_loc > b.to_loc))
        [b, a.move(dist)]
      end
    end

    def self.swap_delete_insert(a, b)
      if a.location <= b.location
        [b.move(1), a]
      else
        [b, a.move(1)]
      end
    end

    def self.swap_delete_alter(a, b)
      if a.location <= b.location
        [b.move(1), a]
      else
        [b, a]
      end
    end

    def self.swap_delete_delete(a, b)
      if a.location <= b.location
        [b.move(1), a]
      else
        [b, a.move(-1)]
      end
    end

    def self.swap_delete_move(a, b)
      dist = 0
      new_from_loc = b.from_loc
      new_to_loc = b.to_loc
      
      if a.location <= b.from_loc
        new_from_loc += 1
        dist += 1
      end
      
      if a.location <= b.to_loc
        new_to_loc += 1
        dist -= 1
      end
      
      [Move.create(new_from_loc, new_to_loc, b.element), a.move(dist)]
    end

    def self.swap_move_insert(a, b)
      dist = 0
      new_from_loc = a.from_loc
      new_to_loc = a.to_loc

      if b.location <= a.from_loc
        new_from_loc += 1
      else
        dist += 1
      end

      if b.location <= a.to_loc
        new_to_loc += 1
      else
        dist -= 1
      end

      [b.move(dist), Move.create(new_from_loc, new_to_loc, a.element)]
    end

    def self.swap_move_alter(a, b)
      if b.location == a.to_loc
        [b.move(a.from_loc - a.to_loc), Move.create(a.from_loc, a.to_loc, b.to_elt)]

      else
        dist = 0
        dist += 1 if (b.location > a.from_loc) || ((b.location == a.from_loc) && (a.from_loc < a.to_loc))
        dist -= 1 if b.location > a.to_loc
        [b.move(dist), a]
      end
    end

    def self.swap_move_delete(a, b)
      if a.to_loc == b.location
        [Delete.new(a.from_loc, b.element), nil]

      else
        dist = 0
        new_from_loc = a.from_loc
        new_to_loc = a.to_loc
        
        if (b.location <= a.from_loc) && !((b.location == a.from_loc) && (a.from_loc < a.to_loc))
          new_from_loc -= 1
        else
          dist += 1
        end
        
        if b.location < a.to_loc
          new_to_loc -= 1
        else
          dist -= 1
        end

        [b.move(dist), Move.create(new_from_loc, new_to_loc, a.element)]
      end
    end

    def self.swap_move_move(a, b)
      foo = lambda do |af, at, bf, bt|
        [Move.create(b.from_loc + bf, b.to_loc + bt, b.element), Move.create(a.from_loc + af, a.to_loc + at, a.element)]
      end

      if (b.from_loc == a.to_loc) && (a.element == b.element)
        if a.from_loc != b.to_loc
          # we have a chain
          [Move.create(a.from_loc, b.to_loc, a.element), nil]
        else
          # we have a revert
          [nil, nil]
        end
      else
        # if the moves are sufficiently far from eachother not to
        # affect each others' indices, then we can simply swap them.
        if (([a.from_loc, a.to_loc].max < [b.from_loc, b.to_loc].min) ||
            ([a.from_loc, a.to_loc].min > [b.from_loc, b.to_loc].max))
          [b, a]

        else
          rv = if ((a.from_loc < a.to_loc) && (b.from_loc < a.to_loc) && (b.to_loc < a.to_loc))
                 if b.to_loc < a.from_loc
                   foo.call(1, 0, 1, 0)
                 else
                   if b.from_loc < a.from_loc
                     foo.call(-1, 0, 0, 1)
                   else
                     foo.call(0, 0, 1, 1)
                   end
                 end
                 
               elsif ((a.from_loc < a.to_loc) && (b.from_loc > a.to_loc) && (b.to_loc <= a.to_loc))
                 if b.to_loc < a.from_loc
                   foo.call(1, 1, 0, 0)
                 else
                   foo.call(0, 1, 0, 1)
                 end
                 
               elsif ((a.from_loc < a.to_loc) && (b.from_loc < a.to_loc) && (b.to_loc >= a.to_loc))
                 if b.from_loc < a.from_loc
                   foo.call(-1, -1, 0, 0)
                 else
                   foo.call(0, -1, 1, 0)
                 end
                 
               elsif ((a.from_loc > a.to_loc) && (b.from_loc > a.from_loc) && (b.to_loc <= a.to_loc))
                 foo.call(1, 1, 0, 0)
                 
               elsif ((a.from_loc > a.to_loc) && (b.from_loc > a.from_loc) && (b.to_loc <= a.from_loc))
                 foo.call(1, 0, 0, -1)
                 
               elsif ((a.from_loc > a.to_loc) && (b.from_loc <= a.from_loc) && (b.to_loc >= a.from_loc))
                 if b.from_loc < a.to_loc
                   foo.call(-1, -1, 0, 0)
                 else
                   foo.call(-1, 0, -1, 0)
                 end
                 
               elsif ((a.from_loc > a.to_loc) && (b.from_loc <= a.from_loc) && (b.to_loc <= a.to_loc))
                 if b.from_loc > b.to_loc
                   foo.call(0, 1, -1, 0)
                 else
                   foo.call(0, -1, 0, -1)
                 end
                 
               elsif ((a.from_loc > a.to_loc) && (b.from_loc <= a.from_loc) && (b.to_loc > a.to_loc))
                 if b.from_loc > a.to_loc
                   foo.call(0, 0, -1, -1)
                 else
                   foo.call(0, -1, 0, -1)
                 end
                 
               else
                 raise "Unhandled move-move case! [#{a} <=> #{b}]"
               end
          # return answer
          rv
        end
      end
    end
  end

  def self.first_contraction(a, i)
    foo = a.each_cons(2).each_with_index.select do |arr,ix|
      x, y = arr
      ((((x.class == Insert) and (y.class == Delete)) or
        ((x.class == Delete) and (y.class == Insert))) and
       (x.location == y.location) and
       (ix > i))
    end
    foo.empty? ? nil : foo.first[1]
  end

  def self.first_relocation(a, i)
    foo = a.each_with_index.select do |x, ix|
      if ((ix > i) and ((x.class == Insert) or (x.class == Delete)))
        pairclass = (x.class == Insert) ? Delete : Insert
        iy = a.index {|y| (y.class == pairclass) and (y.element == x.element) }
        return [ix, iy] unless iy.nil?
      end
    end
    return [nil, nil]
  end

  def self.diff(a, b, options = {})
    a_idx = 0
    rv = Array.new

    Util.diff(a, b).each do |src,elt|
      case src
      when :a
        rv << Diff::Delete.new(a_idx, elt)

      when :b
        rv << Diff::Insert.new(a_idx, elt)
        a_idx += 1

      when :c
        a_idx += 1
      end
    end
    
    if options.has_key?(:detect_alter)
      # now try and detect alterations to the role
      # which we treat separately from other changes.
      fc = -1
      eql_proc = options[:detect_alter]

      while (fc = first_contraction(rv, fc))
        from = rv[fc].class == Delete ? rv[fc] : rv[fc+1]
        to = rv[fc+1].class == Insert ? rv[fc+1] : rv[fc]
        if eql_proc.call(from.element, to.element)
          rv[fc] = Alter.new(from.location, from.element, to.element)
          rv.delete_at(fc+1)
        end
      end
    end

    if options[:detect_move] == true
      fidx = -1
      loop do
        fidx, sidx = first_relocation(rv, fidx)
        break if fidx.nil?

        fidx, sidx = [[fidx, sidx].min, [fidx, sidx].max]
        delidx, insidx = (rv[fidx].class == Delete) ? [fidx, sidx] : [sidx, fidx]
        del_loc = rv[delidx].location
        ins_loc = rv[insidx].location
        movement = rv[(fidx+1)...sidx].map do |a|
          case a
          when Insert 
            1
          when Delete
            -1
          else
            0
          end
        end.reduce(:+)
        movement = 0 if movement.nil?
        if del_loc > ins_loc
          del_loc -= (movement + 1)
        else
          ins_loc -= movement
        end
        rv[fidx] = Move.create(del_loc, ins_loc, rv[insidx].element)
        rv.delete_at(sidx)
      end
    end
    
    return rv
  end

  def self.compose(a, b)
    new_a = Array.new
    new_b = b.clone

    a.reverse.each do |a_act|
      new_a_act = a_act.clone
      new_b.map! do |b_act|
        unless new_a_act.nil? or b_act.nil?
          new_b_act, new_a_act = Swap.swap(new_a_act, b_act)
          new_b_act
        else
          b_act
        end
      end
      new_a.insert(0, new_a_act) unless new_a_act.nil?
    end
    
    return [new_a, new_b.compact]
  end

  def self.split_deletes(a)
    deletes = Array.new
    other = Array.new

    a.each do |act|
      if act.class == Delete
        # deletes are moved before other elements,
        # so we will need to compose them with the
        # others before putting them onto the list.
        other, new_act = Diff::compose(other, [act])
        deletes += new_act

      else
        # non-deletes can be added straight onto the 
        # list of such elements.
        other << act.clone
      end
    end

    return [deletes, other]
  end

  def self.apply(diff, arr)
    diff.inject(arr) do |ax,di|
      di.apply(ax)
    end
  end
end
