require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'test/unit'

class TestReferences < Test::Unit::TestCase

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
  def test_cascading_way_deletion
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

end
