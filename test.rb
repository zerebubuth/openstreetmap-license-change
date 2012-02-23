require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require 'test/unit'

class TestChangeBox < Test::Unit::TestCase
  def setup
    @db = DB.new(1 => Changeset[User[true]],
                 2 => Changeset[User[true]],
                 3 => Changeset[User[false]])
  end 

  # if a node has been edited only by people who have agreed then
  # it should be clean.
  def test_simple_node_clean
    history = [OSM::Node[[0,0], :changeset => 1],
               OSM::Node[[0,0], :changeset => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions)
  end

  # if a node has been created by a person who hasn't agreed then
  # it should be deleted and the one version redacted.
  def test_simple_node_unclean
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Node, 1], Redact[OSM::Node, 1, 1, :hidden]], actions)
  end

  # if a node has been created by a person who hasn't agreed and
  # edited by another who hasn't agreed then it should be deleted 
  # and all the versions redacted.
  def test_simple_node_unclean_multiple_edit
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Node, 1], Redact[OSM::Node, 1, 1, :hidden], Redact[OSM::Node, 1, 2, :hidden]], actions)
  end

  # by the "version zero" rule, then a node which has been created
  # by a disagreer, but later edited by an agreer, doesn't need to
  # be deleted. however, data from the previous version must not be
  # retained. in this case, the data is the same, so the node must
  # be deleted.
  def test_simple_node_unclean_edited_clean_later
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1],
               OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Node, 1], 
                  Redact[OSM::Node, 1, 1, :hidden], 
                  Redact[OSM::Node, 1, 2, :visible]
                 ], actions)
  end

  # if there's more editing, but the position of the node isn't clean
  # then, again, it must be deleted.
  def test_simple_node_unclean_edited_clean_later_tags
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1],
               OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 2, "foo" => "bar"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Node, 1], 
                  Redact[OSM::Node, 1, 1, :hidden], 
                  Redact[OSM::Node, 1, 2, :visible]
                 ], actions)
  end

  # if there are no tags and the position has been changed, then by the
  # "version zero" rule, this can be saved. the final version is OK.
  def test_simple_node_unclean_edited_clean_later_position
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1],
               OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 1, :hidden]
                 ], actions)
  end

  # however, if there are tags, then although we can recover a clean 
  # version of the node, the tags gotta go and the earlier versions
  # must be redacted.
  def test_simple_node_unclean_edited_clean_later_position_with_tags
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"],
               OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 2, "foo" => "bar"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[1,1], :id => 1, :changeset => -1, :version => 2]], 
                  Redact[OSM::Node, 1, 1, :hidden], 
                  Redact[OSM::Node, 1, 2, :visible]
                 ], actions)
  end

  # if a node has been created by a person who has agreed, with
  # some tags, and then a person who hasn't agreed edits those
  # tags then it should be edited to revert to the previous
  # version of that node and the non-agreeing edit should be
  # redacted. 
  def test_simple_node_clean_edited_unclean_later
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1, "foo" => "bar"],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "blah"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 2, "foo" => "bar"]], 
                  Redact[OSM::Node, 1, 2, :hidden]
                 ], actions)
  end 

  # same as above, but there's a subsequent clean edit which adds
  # a new tag to the element. this extra tag isn't tainted in any
  # way by the previous edit, so should be preserved and the extra
  # edit redacted 'visible'.
  def test_simple_node_clean_edited_unclean_later_then_clean_again
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1, "foo" => "bar"],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "blah"],
               OSM::Node[[0,0], :id => 1, :changeset => 2, :version => 3, "foo" => "blah", "bar" => "blah"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 3, "foo" => "bar", "bar" => "blah"]], 
                  Redact[OSM::Node, 1, 2, :hidden],
                  Redact[OSM::Node, 1, 3, :visible]
                 ], actions)
  end 

  # if a node is moved by a decliner then we have to move it back
  def test_node_move
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1],
               OSM::Node[[1,1], :id => 1, :changeset => 3, :version => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 2]], 
                  Redact[OSM::Node, 1, 2, :hidden]
                 ], actions)
  end

  # by the "version zero" rule, a node created without any tags by
  # a decliner and subsequently moved by an agreer should retain 
  # its new position and not be deleted.
  def test_node_create_dirty_then_move_clean
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1],
               OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    # note: the "edit" here would be an identity operation, as the last
    # node version is the same as what we would edit, so the Edit[] 
    # action shouldn't do anything.
    assert_equal([Redact[OSM::Node, 1, 1, :hidden]
                 ], actions)
  end

  # way created by decliner, with no other edits, needs to be deleted
  # and redacted hidden.
  def test_way_simple
    history = [OSM::Way[[1,2,3], :id => 1, :changeset => 3, :version => 1]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Way, 1],
                  Redact[OSM::Way, 1, 1, :hidden]
                 ], actions)
  end
         
  # if a node has been created by an agreer and stuff has been added but meanwhile
  # deleted again, the node is clean (rule: any object that comes out of our bot 
  # edit process must be judged clean by the bot edit process or we're doing something
  # wrong!)
  def test_node_tags_changed_later_restored
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1, "foo" => "bar"],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "bar", "bar" => "blah"],
               OSM::Node[[0,0], :id => 1, :changeset => 2, :version => 3, "foo" => "bar"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden]], actions)
  end 
  
  # a decliner removing tags does not taint an object
  def test_node_tags_removed_by_decliner
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1, "foo" => "bar", "bar" => "blah"],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "bar"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 2, "foo" => "bar"]],
                  Redact[OSM::Node, 1, 2, :hidden]
                 ], actions)
  end 
  
  # if a node has been created by an agreer and then modified by a decliner, then 
  # "cleaned" by an agreer but then another agreer added back the decliner's tag, 
  # possibly reverting the previous agreer's change, we need to redact all versions 
  # that contain data from the decliner...
  def test_node_tags_cleaned_but_then_reverted_to_tainted
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1, "foo" => "bar"],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "bar", "bar" => "blah"],
               OSM::Node[[0,0], :id => 1, :changeset => 2, :version => 3, "foo" => "bar"],
               OSM::Node[[0,0], :id => 1, :changeset => 2, :version => 4, "foo" => "bar", "bar" => "blah"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 4, "foo" => "bar"]],
                  Redact[OSM::Node, 1, 2, :hidden],
                  Redact[OSM::Node, 1, 4, :visible]
                 ], actions)
  end 
  
  # this is a combination of many of the above.
  def test_node_rollercoaster
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"], # created by decliner
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2 ], # tag removed by decliner
               OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 3, "bar" => "baz"], # other tag added, node moved by agreer
               OSM::Node[[1,1], :id => 1, :changeset => 3, :version => 4, "rose" => "red", "bar" => "baz" ], # tag added by decliner
               OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 5, "rose" => "red", "bar" => "baz", "dapper" => "mapper" ], # tag added by agreer
               OSM::Node[[2,2], :id => 1, :changeset => 3, :version => 6, "rose" => "red", "bar" => "baz", "dapper" => "mapper" ], # moved by decliner  
               OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 7, "rose" => "red", "bar" => "baz", "dapper" => "mapper", "e" => "mc**2" ], # tag added by agreer
               OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 8, "rose" => "red", "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "foo" => "bar" ]] # tag re-added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[1,1], :id => 1, :changeset => -1, :version => 8, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2" ]],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :hidden],
                  Redact[OSM::Node, 1, 4, :hidden],
                  Redact[OSM::Node, 1, 5, :visible],
                  Redact[OSM::Node, 1, 6, :hidden],
                  Redact[OSM::Node, 1, 7, :visible],
                  Redact[OSM::Node, 1, 8, :visible],
                 ], actions)
  end
end
