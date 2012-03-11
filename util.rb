# all the little utility stuff that doesn't really belong anywhere
# else...
module Util
  def self.lcs(a, b)
    obj = LCS.new(a, b)
    st = obj.get(0,0)
    st[2]
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
