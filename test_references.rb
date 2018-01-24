#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

class TestReferences < Minitest::Test

  ##
  # this tests that a clean way may have to be deleted if it contains
  # unclean nodes and these nodes are deleted, leaving the way with
  # too few nodes to be valid any more.
  #
  def test_cascading_way_deletion
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  
                  # but this one is OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]]
                },
                :ways => {
                  # loses a node, which makes it invalid and will have to be deleted.
                  1 => [OSM::Way[[1,2], :id => 1, :changeset => 2, :version => 1]]
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Delete[OSM::Way, 1],
                  Delete[OSM::Node, 1]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests that a clean way may have to be edited, even though
  # it's clean, because an unclean node is deleted and cannot be
  # referenced any more.
  #
  def test_remove_dirty_node_from_way
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  
                  # but these ones are OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]], 
                  3 => [OSM::Node[[1,1], :id => 3, :changeset => 1, :version => 1]]
                },
                :ways => {
                  # despite the clean-ness of this one it will have to be edited to 
                  # get rid of the node which will be deleted because it's unclean.
                  1 => [OSM::Way[[1,2,3], :id => 1, :changeset => 2, :version => 1]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Edit[OSM::Way[[2,3], :id => 1, :changeset => -1, :version => 1]],
                  Delete[OSM::Node, 1]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests removing an unclean node from a way, where the node
  # is at the same time the first and last node in the way.
  #
  def test_remove_dirty_node_from_way_twice
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  
                  # but these ones are OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]], 
                  3 => [OSM::Node[[1,1], :id => 3, :changeset => 1, :version => 1]]
                },
                :ways => {
                  # despite the clean-ness of this one it will have to be edited to 
                  # get rid of the node which will be deleted because it's unclean.
                  1 => [OSM::Way[[1,2,3,1], :id => 1, :changeset => 2, :version => 1]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Edit[OSM::Way[[2,3], :id => 1, :changeset => -1, :version => 1]],
                  Delete[OSM::Node, 1]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests removing two nodes from a way - one clean node that was added
  # by a decliner, and one unclean node that was added by an agreer!
  #
  def test_remove_two_nodes_from_way_for_different_reasons
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  
                  # but these ones are OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]], 
                  3 => [OSM::Node[[1,1], :id => 3, :changeset => 1, :version => 1]],
                  4 => [OSM::Node[[1,1], :id => 4, :changeset => 1, :version => 1]]
                },
                :ways => {
                  # way created with nodes 1,2,3 (1 unclean) and node 4 later added by decliner
                  1 => [OSM::Way[[1,2,3], :id => 1, :changeset => 2, :version => 1],  
                        OSM::Way[[1,2,3,4], :id => 1, :changeset => 3, :version => 2]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Edit[OSM::Way[[2,3], :id => 1, :changeset => -1, :version => 2]],
                  # Redact[OSM::Way, 1, 2, :hidden],  # required in this test?
                  Delete[OSM::Node, 1]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests removing two nodes from a way - one clean node that was added
  # by a decliner, and one unclean node that was added by an agreer - leaving
  # the way with only one node and thus subject to deletion.
  def test_remove_two_nodes_from_way_for_different_reasons_resulting_in_one_node_way
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  
                  # but these ones are OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]], 
                  3 => [OSM::Node[[1,1], :id => 3, :changeset => 1, :version => 1]]
                },
                :ways => {
                  # way created with nodes 1,2 (1 unclean) and node 3 later added by decliner
                  1 => [OSM::Way[[1,2], :id => 1, :changeset => 2, :version => 1],  
                        OSM::Way[[1,2,3], :id => 1, :changeset => 3, :version => 2]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Delete[OSM::Way, 1],
                  # Redact[OSM::Way, 1, 2, :hidden],  # required in this test?
                  Delete[OSM::Node, 1]
                 ], 
                 bot.as_changeset)
  end 


  ##
  # this tests that a clean way does *not* have to be edited if a 
  # participating node has to be reverted to an earlier state but not
  # deleted.
  #
  def test_way_remains
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to revert this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1],
                        OSM::Node[[2,2], :id => 1, :changeset => 3, :version => 2]], 
                  
                  # these ones are OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]], 
                  3 => [OSM::Node[[1,1], :id => 3, :changeset => 1, :version => 1]]
                },
                :ways => {
                  # Will not need editing
                  1 => [OSM::Way[[1,2,3], :id => 1, :changeset => 2, :version => 1]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 2]], 
                  # Redact[OSM::Node, 1, 2, :hidden]  # is this needed???
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests that a clean relation may have to be edited, 
  # because an unclean node is deleted and cannot be
  # referenced any more.
  #
  def test_remove_dirty_node_from_relation
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  
                  # but these ones are OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]], 
                  3 => [OSM::Node[[1,1], :id => 3, :changeset => 1, :version => 1]]
                },
                :relations => {
                  # despite the clean-ness of this one it will have to be edited to 
                  # get rid of the node which will be deleted because it's unclean.
                  1 => [OSM::Relation[[ [OSM::Node,1,"first"] , [OSM::Node,2,"second"] , [OSM::Node,3,"third"] ], :id => 1, :changeset => 2, :version => 1]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Edit[OSM::Relation[[ [OSM::Node,2,"second"] , [OSM::Node,3,"third"] ], :id => 1, :changeset => -1, :version => 1]],
                  Delete[OSM::Node, 1]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests that a relation losing all its members will  
  # be deleted, and not mess up the diff upload.
  # See https://trac.openstreetmap.org/ticket/4471
  #
  def test_empty_relation_remains
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete these
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 3, :version => 1]], 
                  3 => [OSM::Node[[1,1], :id => 3, :changeset => 3, :version => 1]]
                },
                :relations => {
                  # will lose all members
                  1 => [OSM::Relation[[ [OSM::Node,1,"first"] , [OSM::Node,2,"second"] , [OSM::Node,3,"third"] ], :id => 1, :changeset => 2, :version => 1]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Delete[OSM::Relation, 1],
                  Delete[OSM::Node, 1],
                  Delete[OSM::Node, 2],
                  Delete[OSM::Node, 3]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests that a clean relation may have to be edited, 
  # because an unclean way member is deleted and cannot be
  # referenced any more.
  #
  def test_remove_dirty_way_from_relation
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # both ok
                  1 => [OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 1]], 
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]]
                },
                :ways => {
                  # not ok
                  1 => [OSM::Way[[1,2], :id => 1, :changeset => 3, :version => 1]]
                }, 
                :relations => {
                  # despite the clean-ness of this one it will have to be edited to 
                  # get rid of the way.
                  1 => [OSM::Relation[[ [OSM::Node,1,"first"] , [OSM::Node,2,"second"] , [OSM::Way,1,"third"] ], :id => 1, :changeset => 2, :version => 1]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Edit[OSM::Relation[[ [OSM::Node,1,"first"] , [OSM::Node,2,"second"] ], :id => 1, :changeset => -1, :version => 1]],
                  Delete[OSM::Way, 1]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # this tests that a clean relation may have to be edited, 
  # because a clean way member has to be deleted due to consisting
  # of too many unclean nodes, and the way now cannot be 
  # referenced by the relation any more.
  #
  def test_remove_dirty_node_from_way_and_way_from_relation
    db = DB.new(:changesets => {
                  1 => Changeset[User[true]],
                  2 => Changeset[User[true]],
                  3 => Changeset[User[false]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]], 
                  
                  # but this is OK
                  2 => [OSM::Node[[1,1], :id => 2, :changeset => 1, :version => 1]], 
                },
                :ways => {
                  # loses a node, which makes it invalid and will have to be deleted even though clean
                  1 => [OSM::Way[[1,2], :id => 1, :changeset => 2, :version => 1]]
                }, 
                :relations => {
                  # loses one dirty node and the clean way, keeps the clean node
                  1 => [OSM::Relation[[ [OSM::Node,1,"first"] , [OSM::Node,2,"second"] , [OSM::Way,1,"third"] ], :id => 1, :changeset => 2, :version => 1]] 
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Edit[OSM::Relation[[ [OSM::Node,2,"second"] ], :id => 1, :changeset => -1, :version => 1]],
                  Delete[OSM::Way, 1],
                  Delete[OSM::Node, 1]
                 ], 
                 bot.as_changeset)
  end 

  ##
  # This tests that cascading relations are deleted in the correct order
  # if deletions elsewhere cause them to be deleted
  def test_remove_relations_in_order
    db = DB.new(:changesets => {
                  1 => Changeset[User[false]],
                  2 => Changeset[User[true]]
                },
                :nodes => {
                  # we'll have to delete this
                  1 => [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1]],
                },
                :relations => {
                  # loses node, so has to be deleted
                  1 => [OSM::Relation[[ [OSM::Node,1,"first"] ], :id => 1, :changeset => 2, :version => 1]] ,
                  # loses relation, so has to be deleted *first*
                  2 => [OSM::Relation[[ [OSM::Relation,1,"first"] ], :id => 2, :changeset => 2, :version => 1]]
                })
    bot = ChangeBot.new(db)
    bot.process_all!

    assert_equal([Delete[OSM::Relation, 2],
                  Delete[OSM::Relation, 1],
                  Delete[OSM::Node, 1]
                  ],
                  bot.as_changeset)
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

