#!/usr/bin/env ruby

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

class TestNeedsClarity < MiniTest::Unit::TestCase
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
  end 
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

