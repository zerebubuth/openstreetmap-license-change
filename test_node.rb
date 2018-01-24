#!/usr/bin/env ruby
# encoding: UTF-8

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

class TestNode < Minitest::Test

  # Setup prior to each of the node tests below
  # Changesets 1 & 2 are by agreers. Changeset 3 is by a disagreer.
  # References to these numbers appear in the tests below, while the
  # the actual data of the changesets is initialised differently for
  # each test.
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]], #agreer
                   2 => Changeset[User[true]], #agreer
                   3 => Changeset[User[false]] #disagreer
                 })
  end

  # if a node has been edited only by people who have agreed then
  # it should be clean.
  def test_simple_node_clean
    history = [OSM::Node[[0,0], :changeset => 1],
               OSM::Node[[0,0], :changeset => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions) #the bot should take no actions (empty actions array)
  end

  # if a node has been created by a person who hasn't agreed then
  # it should be deleted and the one version redacted.
  def test_simple_node_unclean
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1]] #node created in changeset 3 (by a disagreer)
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)

    # bot should return an array of actions. These are structs defined in actions.rb
    assert_equal([Delete[OSM::Node, 1],  #node should be deleted
                  Redact[OSM::Node, 1, 1, :hidden]  #version 1 of node id 1 should be redacted
                 ], actions)
  end

  # if a node has been created by a person who hasn't agreed and
  # edited by another who hasn't agreed then it should be deleted
  # and all the versions redacted.
  def test_simple_node_unclean_multiple_edit
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Node, 1],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :visible] # <- trivial edit, so visible.
                 ], actions)
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

  # ...but we can keep any tags added by the agreeing mapper
  def test_simple_node_unclean_edited_clean_later_position_with_good_and_bad_tags
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"],
               OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 2, "foo" => "bar", "fee" => "fie"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[1,1], :id => 1, :changeset => -1, :version => 2, "fee" => "fie"]],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :visible]
                 ], actions)
  end

  # But a trivial change to a tag cannot clean it
  def test_simple_node_unclean_edited_clean_later_position_bad_tag_trivial_change
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bars"],
               OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 2, "foo" => "bar's"]]
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
    assert_equal([], actions)
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
                  Redact[OSM::Node, 1, 2, :visible],
                  Redact[OSM::Node, 1, 4, :hidden],
                  Redact[OSM::Node, 1, 5, :visible],
                  Redact[OSM::Node, 1, 6, :hidden],
                  Redact[OSM::Node, 1, 7, :visible],
                  Redact[OSM::Node, 1, 8, :visible],
                 ], actions)
  end


  # An object with many versions may have had tainted content in the past which has long since vanished
  # Here we ensure that no redaction will occur to versions after the final removal of the last taint

  def test_node_reformed_ccoholic_simple
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"], # created by decliner
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2 ], # tag removed by decliner
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 3, "sugar" => "sweet" ], # tag added by decliner
               OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 4, "sugar" => "sweet", "bar" => "baz"], # other tag added, node moved by agreer
               OSM::Node[[1,1], :id => 1, :changeset => 3, :version => 5, "sugar" => "sweet", "rose" => "red", "bar" => "baz" ], # tag added by decliner
               OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 6, "sugar" => "sweet", "bar" => "baz", "dapper" => "mapper" ], # tag added by agreer, dirty tag removed
               OSM::Node[[2,2], :id => 1, :changeset => 1, :version => 7, "bar" => "baz", "dapper" => "mapper" ], # moved by agreer
               OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 8, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2" ], # tag added by agreer
               OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "really" => "fresh" ]] # Brand new tag
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)

    assert_equal([Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :visible], # tag deletion
                  Redact[OSM::Node, 1, 3, :hidden],
                  Redact[OSM::Node, 1, 4, :visible],
                  Redact[OSM::Node, 1, 5, :hidden],
                  Redact[OSM::Node, 1, 6, :visible],
                 ], actions)
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
    # and then hides version 6 and before because v6-v3 have the "sugar=sweet" tag which was added
    # by a decliner and is therefore tainted, and v1 & v2 are decliner edits.
    assert_equal([Edit[OSM::Node[[2,2], :id => 1, :changeset => -1, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2" ]],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :visible],
                  Redact[OSM::Node, 1, 3, :hidden],
                  Redact[OSM::Node, 1, 4, :visible],
                  Redact[OSM::Node, 1, 5, :hidden],
                  Redact[OSM::Node, 1, 6, :visible],
                  Redact[OSM::Node, 1, 9, :visible],
                 ], actions)
  end

  # Identical to test_node_reformed_ccoholic but the tag is reintroduced in the same change set as it is deleted
  # LWG has concluded that this may be risky and would prefer to see odbl=clean used in such cases with no tag deletion and replacement

  def test_node_reformed_ccoholic_too_hasty
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"], # created by decliner
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "bar", "diddle" => "dum" ], # tag added by decliner
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 3, "foo" => "bar", "diddle" => "dum", "sugar" => "sweet" ], # tag added by decliner
               OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 4, "foo" => "bar", "diddle" => "dum", "sugar" => "sweet", "bar" => "baz"], # other tag added, node moved by agreer
               OSM::Node[[1,1], :id => 1, :changeset => 3, :version => 5, "foo" => "bar", "diddle" => "dum", "sugar" => "sweet", "bar" => "baz", "rose" => "red"], # tag added by decliner
               OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 6, "bar" => "baz", "dapper" => "mapper" ], # tag added by agreer, dirty tags removed
               OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 7, "bar" => "baz", "dapper" => "mapper", "foo" => "bar"], # Previously dirty tag added back in **same changeset as deletion**
               OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 8, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "foo" => "bar" ], # tag added by agreer
               OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "foo" => "bar", "bored" => "yet?" ]] # new tag added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)

    assert_equal([Edit[OSM::Node[[2,2], :id => 1, :changeset => -1, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "bored" => "yet?" ]],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :hidden],
                  Redact[OSM::Node, 1, 3, :hidden],
                  Redact[OSM::Node, 1, 4, :visible],
                  Redact[OSM::Node, 1, 5, :hidden],
                  #         Redact[OSM::Node, 1, 6, :visible],   # Surely this version is clean and needs no redaction?
                  Redact[OSM::Node, 1, 7, :visible],
                  Redact[OSM::Node, 1, 8, :visible],
                  Redact[OSM::Node, 1, 9, :visible],
                 ], actions)
  end

  # We can even keep (some...) changes to a tag created by a non-agreeing mapper
  #
  # NOTE: needs some thought.
  # the issue here is whether the *keys* of tags contain any copyright status.
  # here, the key is changed from "foo"="bar" to "foo"="feefie", which is a
  # Significant Change to the value (see tests for that in test_tags.rb), but
  # is no change to the key.
  #
  # if we assume that keys are potentially copyrightable then we must reject
  # the following test case, and potentially leave a lot of "highway"= and
  # "name"= tags in an old state (or remove them). on the other hand, some
  # tags may well have copyright-worthy information in the keys, given that
  # they're free-form strings just like the values.
  def test_simple_node_unclean_edited_clean_later_position_bad_tag_changed
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "wibble" => "wobble", "foo" => "bar"],
               OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 2, "wibble" => "wobble", "foo" => "feefie"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[1,1], :id => 1, :changeset => -1, :version => 2, "foo" => "feefie"]],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :visible]
                 ], actions)
  end

  # a node created by an agreer then touched by a decliner with no actual modifications
  def test_node_no_change
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1, "foo" => "bar"],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "bar"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions)
  end

  # simplified test case for test_automatic_node30100000
  # a node created by an agreer then touched by a decliner modifying the created_by tag
  # when the bot is editing it should drop the created_by
  def test_node_update_created_by
    history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1, "created_by" => "Potlatch"],
               OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "created_by" => "JOSM", "name"=>"foo"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 2]], # drop created_by
                  Redact[OSM::Node, 1, 2, :hidden]], actions)
  end

  # a node touched by certain editors can have a small offset due to floating point operations
  def test_node_fp_bug
    history = [OSM::Node[[0.1234567,0], :id => 1, :changeset => 3, :version => 1, "created_by" => "JOSM"],
               OSM::Node[[0.1234566,0], :id => 1, :changeset => 1, :version => 2, "created_by" => "Potlatch 1.4", "name"=>"foo"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[klass=OSM::Node,element_id=1],
                  Redact[OSM::Node, 1, 1, :hidden],
                  Redact[OSM::Node, 1, 2, :visible]], actions)
  end

  def test_node_fp_bug2
    history = [OSM::Node[[0.1234567,0], :id => 1, :changeset => 1, :version => 1, "created_by" => "JOSM"],
               OSM::Node[[0.1234566,0], :id => 1, :changeset => 3, :version => 2, "created_by" => "Potlatch 1.4"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    # Nothing to do, because the decliner didn't make a significant change.
    assert_equal([], actions)
  end

  # The bot tried redacting v3 in production, without a changeset. Why?
  def test_node_wrong_redaction
    history = [OSM::Node[[49.8898997,1.9707186], :id => 1, :changeset => 1, :version => 1], #agreed
               OSM::Node[[49.8898998,1.9707185], :id => 1, :changeset => 3, :version => 2], #declined
               OSM::Node[[49.8898998,1.9707185], :id => 1, :changeset => 2, :version => 3]] #agreed
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    # Nothing to do, because the decliner didn't make a significant change
    assert_equal([], actions)
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end
