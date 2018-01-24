#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './geom'
require 'minitest/unit'

class TestGeom < Minitest::Test

  # checks that, under normal circumstances, the application of
  # a bunch of patches derived from a sequence of versions form
  # the same sequence when merged on top of each other. in other
  # words, that the patch taking and application works.
  #
  def test_relation_diff_inserts
    geoms = [[],
             [                    [OSM::Way,29336166]], 
             [                    [OSM::Way,29336166], [OSM::Way,29377987]],
             [[OSM::Way,9650915], [OSM::Way,29336166], [OSM::Way,29377987]],
             [[OSM::Way,9650915], [OSM::Way,29336166], [OSM::Way,29377987], [OSM::Way,29335519]]
            ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  def test_relation_diff_deletes
    geoms = [[[OSM::Way,9650915], [OSM::Way,29336166], [OSM::Way,29377987], [OSM::Way,29335519]],
             [[OSM::Way,9650915], [OSM::Way,29336166], [OSM::Way,29377987]],
             [                    [OSM::Way,29336166], [OSM::Way,29377987]],
             [                    [OSM::Way,29336166]],
             []
            ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  def test_relation_diff_inserts_and_deletes
    geoms = [[],
             [[OSM::Way,9650915], [OSM::Way,29336166]], 
             [                    [OSM::Way,29336166], [OSM::Way,29377987]],
             [[OSM::Way,9650915], [OSM::Way,29336166], [OSM::Way,29377987]],
             [[OSM::Way,9650915],                      [OSM::Way,29377987], [OSM::Way,29335519]]
            ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  def test_relation_diff_moves
    geoms = [[[OSM::Way,1], [OSM::Way,2], [OSM::Way,3], [OSM::Way,4]], 
             [[OSM::Way,2], [OSM::Way,1], [OSM::Way,3], [OSM::Way,4]], 
             [[OSM::Way,2], [OSM::Way,3], [OSM::Way,1], [OSM::Way,4]], 
             [[OSM::Way,2], [OSM::Way,3], [OSM::Way,4], [OSM::Way,1]], 
             [[OSM::Way,2], [OSM::Way,3], [OSM::Way,4], [OSM::Way,1]], 
             [[OSM::Way,1], [OSM::Way,2], [OSM::Way,3], [OSM::Way,4]]
            ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  def test_relation_diff_moves_reverse
    geoms = [[[OSM::Way,1], [OSM::Way,2], [OSM::Way,3], [OSM::Way,4]], 
             [[OSM::Way,4], [OSM::Way,1], [OSM::Way,2], [OSM::Way,3]], 
             [[OSM::Way,3], [OSM::Way,4], [OSM::Way,1], [OSM::Way,2]], 
             [[OSM::Way,2], [OSM::Way,3], [OSM::Way,4], [OSM::Way,1]], 
             [[OSM::Way,1], [OSM::Way,2], [OSM::Way,3], [OSM::Way,4]]
            ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  def test_relation_diff_alter
    geoms = [[[OSM::Way,1], [OSM::Way,2,"foo123"], [OSM::Way,3]],
             [[OSM::Way,1], [OSM::Way,2,"bar456"], [OSM::Way,3]],
             [[OSM::Way,1], [OSM::Way,2,"bat789"], [OSM::Way,3]]
             ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  def test_relation_diff_alter_front
    geoms = [[[OSM::Way,1,"foo123"], [OSM::Way,2], [OSM::Way,3]],
             [[OSM::Way,1,"bar456"], [OSM::Way,2], [OSM::Way,3]],
             [[OSM::Way,1,"bat789"], [OSM::Way,2], [OSM::Way,3]]
             ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  def test_relation_diff_alter_back
    geoms = [[[OSM::Way,1], [OSM::Way,2], [OSM::Way,3,"foo123"]],
             [[OSM::Way,1], [OSM::Way,2], [OSM::Way,3,"bar456"]],
             [[OSM::Way,1], [OSM::Way,2], [OSM::Way,3,"bat789"]]
             ].map {|g| OSM::Relation[g]}
    check_diff_apply(geoms)
  end

  # this is a very cut-down, geometry-only version of one
  # of the auto tests, which is failing because the non-applied
  # insert by a decliner is throwing off the diff indexes later
  # on in the process.
  def test_relation_partial_insertion
    geoms = [[[OSM::Way,1],               [OSM::Way,3]],
             [[OSM::Way,1], [OSM::Way,2], [OSM::Way,3]],
             [[OSM::Way,1], [OSM::Way,2]              ],
             [[OSM::Way,1],               [OSM::Way,3]],
             ].map {|g| OSM::Relation[g]}
    diffs = geoms.each_cons(2).map {|a, b| Geom.diff(a, b)}
    g = geoms[0].geom

    # apply diffs, with the first being a "decliner" diff
    state = []
    g = diffs[0].apply(g, :only => :deleted, :state => state)
    g = diffs[1].apply(g, :state => state)
    g = diffs[2].apply(g, :state => state)
    
    # the "decliner" diff adds way 2, but this is deleted in
    # the final diff, so the result should be the same as the
    # first version of the geometry: ways 1 & 3
    assert_equal(g, OSM::Relation[[[OSM::Way,1], [OSM::Way,3]]].geom)
  end

  private
  
  def check_diff_apply(geoms)
    x = OSM::Relation[[]]
    x.geom = geoms.first.geom

    geoms.each_cons(2).each do |a, b|
      d = Geom.diff(a, b)
      x.geom = d.apply(x.geom)
      #puts
      #puts "a: #{a.members}"
      #puts "b: #{b.members}"
      #puts "d: #{d}"
      #puts "x: #{x.members}"
      assert_equal(b, x)
    end
  end
end


if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

