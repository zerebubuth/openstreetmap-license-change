require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'test/unit'

class TestNeedsClarity < Test::Unit::TestCase
  def setup
    @db = DB.new(1 => Changeset[User[true]],
                 2 => Changeset[User[true]],
                 3 => Changeset[User[false]])
  end 

  # this is a node with some early bad content all of which has been eradicated many versions ago
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
    assert_equal([Edit[OSM::Node[[2,2], :id => 1, :changeset => -1, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2" ]],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :hidden],
                  Redact[OSM::Node, 1, 3, :hidden],
                  Redact[OSM::Node, 1, 4, :visible],
                  Redact[OSM::Node, 1, 5, :hidden],
                  Redact[OSM::Node, 1, 6, :visible],
                 ], actions)
  end

  # as above, but replacing nodes and adding too
  # (where the node-list contains new agreeing IP (i.e. addition of nodes 5/6) and old declined IP (i.e. node 4),
  #  there's no simple solution but we should probably go by node ID)
  #
  # NOTE: needs some thought.
  # it's easy to think of node 4 here "replacing" node 2, but what if the difference between them were
  # greater? would the sequence [1,2,3] -> [1,4,5,3] -> [1,4,5,3,6,7] be reversed as [1,2,3,6,7]?
  # or [1,2,3,4] -> [1,5,4] -> [1,5,4,6,7] as [1,2,3,4,6,7]?
  #
  # is the situation the same at other positions in the list, e.g: [1,2,3] -> [1,4,5] -> [6,1,4,5] as
  # [6,1,2,3]?
  #
  # the case to consider is whether we consider deletions to be OK regardless of the author. this is
  # perhaps motivated by the deletion of nodes from a way often being the result of the deletion of
  # those referenced nodes, where that deletion is not a copyright-worthy action as it adds no new
  # information.
  def test_way_nodes_replaced_and_added
    history = [OSM::Way[[1,2,3    ], :id=>1, :changeset=>1, :version=>1, "highway"=>"trunk"], # created by agreer
               OSM::Way[[1,4,3    ], :id=>1, :changeset=>3, :version=>2, "highway"=>"trunk"], # node removed by decliner
               OSM::Way[[1,4,3,5,6], :id=>1, :changeset=>2, :version=>3, "highway"=>"primary"]] # tag change and node addition by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3,5,6], :id=>1, :changeset=>-1, :version=>3, "highway"=>"primary"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible] # needs to be redacted - node 4 still in this version
                 ], actions)
  end

end
