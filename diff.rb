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

    def swap(other)
      if self.location < other.location
        [other.move(-1), self]
      elsif self.location == other.location
        case other
        when Insert
          [other, self.move(1)]
        when Delete
          [nil, nil]
        when Alter
          [Insert.new(self.location, other.to_elt), nil]
        end
      else
        case other
        when Insert
          [other, self.move(1)]
        when Delete
          [other, self.move(-1)]
        when Alter
          [other, self]
        end
      end
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

    def swap(other)
      if self.location <= other.location
        [other.move(1), self]
      elsif self.location == other.location
        case other
        when Insert
          [other.move(1), self]
        when Delete
          [other.move(1), self]
        when Alter
          [Delete.new(self.location,other.from_elt), nil]
        end
      else
        case other
        when Insert
          [other, self.move(1)]
        when Delete
          [other, self.move(-1)]
        when Alter
          [other, self]
        end
      end
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

    def swap(other)
      if self.location < other.location
        [other.move(0), self]
      elsif self.location == other.location
        case other
        when Insert
          [other, self.move(1)]
        when Delete
          [Delete.new(self.location, self.from_elt), nil]
        when Alter
          [Alter.new(self.location, self.from_elt, other.to_elt)]
        end
      else
        case other
        when Insert
          [other, self.move(1)]
        when Delete
          [other, self.move(-1)]
        when Alter
          [other, self]
        end
      end
    end
  end

  def self.first_contraction(a)
    foo = a.each_cons(2).each_with_index.select do |arr,ix|
      x, y = arr
      ((((x.class == Insert) and (y.class == Delete)) or
        ((x.class == Delete) and (y.class == Insert))) and
       (x.location == y.location))
    end
    foo.empty? ? nil : foo.first[1]
  end

  def self.diff(a, b)
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
    
    # now try and detect alterations to the role
    # which we treat separately from other changes.
    while (fc = first_contraction(rv))
      from = rv[fc].class == Delete ? rv[fc] : rv[fc+1]
      to = rv[fc+1].class == Insert ? rv[fc+1] : rv[fc]
      rv[fc] = Alter.new(from.location, from.element, to.element)
      rv.delete_at(fc+1)
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
          new_b_act, new_a_act = new_a_act.swap(b_act)
          new_b_act
        else
          b_act
        end
      end
      new_a.insert(0, new_a_act) unless new_a_act.nil?
    end
    
    return [new_a, new_b.compact]
  end

  def self.apply(diff, arr)
    diff.inject(arr) do |ax,di|
      di.apply(ax)
    end
  end
end
