#!/usr/bin/env ruby
# encoding: UTF-8

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

############################################################
#
# NOTE: the tests here have been put here because someone
# needs to have a serious think about what the result of 
# the license change should be on these cases. please see
# the comments before and inside the tests for more 
# details.
#
############################################################

class TestNeedsClarity < Minitest::Test
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
  end 
  
  # Russians write the street names as either "foo street" or "street foo" swaping theese should not be a segnificant edit
  def test_way_name_swap
    history = [OSM::Way[[1,2,3], :id=>1, :changeset=>1, :version=>1, "highway"=>"residental"], # created by agreer
               OSM::Way[[1,2,3], :id=>1, :changeset=>3, :version=>2, "highway"=>"residental", "name"=>"ул. Гая"], # name added by decliner
               OSM::Way[[1,2,3], :id=>1, :changeset=>2, :version=>3, "highway"=>"residental", "name"=>"Гая ул."]] # name swapped around by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3], :id=>1, :changeset=>-1, :version=>3, "highway"=>"residental"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]
                 ], actions)
  end
  
  # The type of a relation is no more copyrightable then the type of an object
  def test_relation_type_multipolygon
    history = [OSM::Relation[[ [OSM::Way,1,""]], :id=>1, :changeset=>3, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,2,""]], :id=>1, :changeset=>1, :version=>2, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation,1,1,:hidden]], actions)
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

