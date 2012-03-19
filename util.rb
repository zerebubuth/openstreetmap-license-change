# all the little utility stuff that doesn't really belong anywhere
# else...
module Util
  def self.lcs(a, b)
    obj = LCS.new(a, b)
    st = obj.get(0,0)
    st[2]
  end

  def self.diff(a, b)
    c = Util.lcs(a, b)
    d = Array.new
    ai = 0
    bi = 0
    c.each do |e|
      while a[ai] != e
        d << [:a, a[ai]]
        ai += 1
      end
      while b[bi] != e
        d << [:b, b[bi]]
        bi += 1
      end
      d << [:c, e]
      ai += 1
      bi += 1
    end
    d += a[ai..-1].map {|e| [:a, e]}
    d += b[bi..-1].map {|e| [:b, e]}
    d
  end

  def self.diff_split(a_k, a_v, b_k, b_v)
    c = Util.diff(a_k, b_k)
    c_v = Array.new
    ai = 0
    bi = 0
    c.each do |o,e|
      case o
      when :a
        # nothing - A is discarded
        ai += 1

      when :b
        # new in B, so need B's attribute
        c_v << b_v[bi]
        bi += 1

      when :c
        # unmodified, so take A's attribute
        c_v << a_v[ai]
        ai += 1
        bi += 1
      end
    end
    c_v
  end

  private
  
  class LCS
    def initialize(a, b)
      @a, @b = a, b
      @state = Hash.new
    end

    def get(i, j)
      if @state[[i,j]].nil?
        compute!(i, j)
      end
      @state[[i,j]]
    end

    def last_of(ary, x)
      lst = ary.zip(0..(ary.length-1)).select {|a,i| a == x}.last
      lst.nil? ? nil : lst[1]
    end

    def trunc(ary, idx)
      if idx <= 0
        []
      else
        ary[0..(idx-1)]
      end
    end

    def compute!(i, j)
      states = Array.new
      if i < @a.length
        ai = @a[i]
        a_head, b_head, tail = get(i+1, j)
        bhi = last_of(b_head, ai)
        if bhi.nil?
          states << [[ai] + a_head, b_head, tail]
        else
          states << [[], trunc(b_head, bhi), [ai] + tail]
        end
      end
      if j < @b.length
        bj = @b[j]
        a_head, b_head, tail = get(i, j+1)
        ahi = last_of(a_head, bj)
        if ahi.nil?
          states << [a_head, [bj] + b_head, tail]
        else
          states << [trunc(a_head, ahi), [], [bj] + tail]
        end
      end
      if states.empty?
        @state[[i,j]] = [[],[],[]]
      else
        states.sort_by! {|x| x[2].length}
        @state[[i,j]] = states.last
      end
    end

  end
end
