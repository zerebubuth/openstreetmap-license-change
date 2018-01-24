#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

class TestUtil < Minitest::Test

  # testing the longest common substring utility function. this isn't
  # license-related directly, but it's used in the way/relation geometry
  # handling and diffing routines.
  def test_util_lcs
    assert_equal([], Util::lcs([1,2,3],[4,5,6]))
    assert_equal([], Util::lcs([], []))
    assert_equal([], Util::lcs([1], [2]))
    assert_equal([1], Util::lcs([1], [1]))
    assert_equal([1,2,3], Util::lcs([1,2,3],[1,2,3]))
    assert_equal([2,3], Util::lcs([1,2,3],[2,3,4]))
    assert_equal([2,3,2], Util::lcs([1,2,3,2],[2,3,2,4]))
    assert_equal([2,3,2,2], Util::lcs([1,2,3,2,2],[2,3,2,4,2]))
    assert_equal([2,3,2,2], Util::lcs([2,3,2,4,2],[1,2,3,2,2]))
    assert_equal([2,3,2,2,2], Util::lcs([1,2,3,2,3,3,4,2,2,5,6],[2,3,2,2,2]))
    assert_equal([2,3,2,2,2], Util::lcs([2,3,2,2,2],[1,2,3,2,3,3,4,2,2,5,6]))
  end

  def test_util_lcs_efficiency
    # make a very long pair of sequences, and test the LCS algorithm doesn't
    # take too long. if this takes way too long, then it's unlikely that the
    # bot process will run in any decent length of time.
    a, b, c = [], [], []
    100.times do
      n = rand(10)
      n.times do 
        x = rand(100)
        a << x
        b << x
        c << x
      end
      # add some stuff that isn't in the list
      a << 101 
      b << 102
    end

    c2 = Util::lcs(a, b)

    assert_equal(c, c2)
  end

  def test_util_diff
    assert_equal([], Util::diff([], []))
    assert_equal([[:c, 1], [:c, 2], [:c, 3]], Util::diff([1,2,3], [1,2,3]))
    assert_equal([[:c, 1], [:a, 2], [:c, 3]], Util::diff([1,2,3], [1,3]))
    assert_equal([[:c, 1], [:b, 2], [:c, 3]], Util::diff([1,3], [1,2,3]))
    assert_equal([[:a, 1], [:a, 2], [:a, 3]], Util::diff([1,2,3], []))
    assert_equal([[:b, 1], [:b, 2], [:b, 3]], Util::diff([], [1,2,3]))
    assert_equal([[:a, 1], [:c, 2], [:c, 3], [:b, 4]], Util::diff([1,2,3], [2,3,4]))
    assert_equal([[:a, 1], [:a, 2], [:b, 3], [:b, 4]], Util::diff([1,2], [3,4]))
  end

  def test_util_diff_split
    assert_equal([true, true, true], Util::diff_split([], [], [1,2,3], [true, true, true]))
    assert_equal([], Util::diff_split([1,2,3], [false, false, false], [], []))
    assert_equal([false, false, false], Util::diff_split([1,2,3], [false, false, false], [1,2,3], [true, true, true]))
    assert_equal([false, true, false], Util::diff_split([1,3], [false, false], [1,2,3], [true, true, true]))
    assert_equal([true, true, false], Util::diff_split([1,3], [true, false], [1,2,3], [true, true, true]))
  end

end


if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

