require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'test/unit'

class TestUtil < Test::Unit::TestCase

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

end

