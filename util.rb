# all the little utility stuff that doesn't really belong anywhere
# else...
module Util
  def self.lcs(a, b)
    # NOTE: LCS implementation under GFDL 1.2 from 
    #   http://rosettacode.org/wiki/Longest_common_subsequence#Ruby
    # slightly modified to use Array instead of String.
    lengths = Array.new(a.size+1) { Array.new(b.size+1) { 0 } }
    # row 0 and column 0 are initialized to 0 already
    a.each_with_index { |x, i|
      b.each_with_index { |y, j|
        if x == y
          lengths[i+1][j+1] = lengths[i][j] + 1
        else
          lengths[i+1][j+1] = \
          [lengths[i+1][j], lengths[i][j+1]].max
        end
      }
    }
    # read the substring out from the matrix
    result = Array.new
    x, y = a.size, b.size
    while x != 0 and y != 0
      if lengths[x][y] == lengths[x-1][y]
        x -= 1
      elsif lengths[x][y] == lengths[x][y-1]
        y -= 1
      else
        # assert a[x-1] == b[y-1]
        result << a[x-1]
        x -= 1
        y -= 1
      end
    end
    result.reverse
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
end
