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

    # this is a node with some early bad content all of which has been eradicated many versions ago
    # It also has an old tag mapped by a problem mapper reintroduced later by an agreeing mapper.
    # LWG has clarified that such reintroductions are clean _if_ they happen in a separate changeset
    # to the removal of the tag. (that is, tax is put back in a separate context, we apply good faith in the agreeing mapper)
    #
    # NOTE: this needs some thought.
    # the issue is that the "foo=bar" tag re-added in v9 is the same as a tag added by
    # a decliner in v1. on the basis of identity it might be hard to tell whether this
    # is newly-surveyed data, or added by looking at the object's history. 
    #
    # so the question is: can a tag added by an agreer in a later version of an element, 
    # even though it may be similar to a previously-removed tag added by a decliner, be 
    # considered clean?
    #
    def test_node_reformed_ccoholic
        history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"], # created by decliner
        OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2 ], # tag removed by decliner
        OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 3, "sugar" => "sweet" ], # tag added by decliner
        OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 4, "sugar" => "sweet", "bar" => "baz"], # other tag added, node moved by agreer
        OSM::Node[[1,1], :id => 1, :changeset => 3, :version => 5, "sugar" => "sweet", "rose" => "red", "bar" => "baz" ], # tag added by decliner
        OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 6, "sugar" => "sweet", "bar" => "baz", "dapper" => "mapper" ], # tag added by agreer, dirty tag removed
        OSM::Node[[2,2], :id => 1, :changeset => 1, :version => 7, "bar" => "baz", "dapper" => "mapper" ], # moved by agreer  
        OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 8, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2" ], # tag added by agreer
        OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "foo" => "bar" ]] # tag re-added by agreer
        bot = ChangeBot.new(@db)
        actions = bot.action_for(history)
        # this is effectively a revert back to version 8 (because v9 re-adds the tainted "foo=bar" tag)
        #                                                 ^^^^^^^^^^^^^^^^^^^^^^ -- this needs more thought
        # and then hides version 6 and before because v6-v3 have the "sugar=sweet" tag which was added
        # by a decliner and is therefore tainted, and v1 & v2 are decliner edits.
        assert_equal([Redact[OSM::Node, 1, 1, :hidden],
                     Redact[OSM::Node, 1, 2, :hidden],
                     Redact[OSM::Node, 1, 3, :hidden],
                     Redact[OSM::Node, 1, 4, :visible],
                     Redact[OSM::Node, 1, 5, :hidden],
                     Redact[OSM::Node, 1, 6, :visible],
                     ], actions)
    end
    
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

