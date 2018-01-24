#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

class TestExceptions < Minitest::Test
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
    @db.exclude(OSM::Node, [1, 2, 4])

    @db.edit_whitelist = ["n10v1", "n11v2"]
  end 

  # --------------------------------------------------------------------------
  # Tests concerned with special exceptions to the general rule, for which
  # we have special cases.
  # --------------------------------------------------------------------------

  #
  # the UMP import in Poland appear to be receiving a lot of very special
  # attention, and one thing that's needed here is a special exclusion 
  # list of "manually uncleaned" items.
  #
  def test_ump_excluded_node
    # this history would ordinarily indicate a clean node, but we have set
    # up the exclusion list with a set of IDs which should pass some nodes
    # and not others.
    { 1 => true,
      2 => true,
      3 => false,
      4 => true,
      5 => false 
    }.each do |node_id, excluded|
      # simple history, with all-clean, all-agreed editors and even an
      # odbl=clean tag. all of these are overridden by the UMP exclusion
      # list.
      history = [OSM::Node[[0,0], :id => node_id, :changeset => 1, :version => 1, "foo" => "bar"],
                 OSM::Node[[1,0], :id => node_id, :changeset => 1, :version => 2, "foo" => "bar"],
                 OSM::Node[[1,1], :id => node_id, :changeset => 1, :version => 3, "foo" => "bar", "odbl" => "clean"]]

      bot = ChangeBot.new(@db)
      actions = bot.action_for(history)

      if excluded
        # if excluded, we should delete and redact the full history, regardless
        # of the clean-ness of the item under the normal rules.
        assert_equal([Delete[OSM::Node, node_id], 
                      Redact[OSM::Node, node_id, 1, :hidden],
                      Redact[OSM::Node, node_id, 2, :hidden],
                      Redact[OSM::Node, node_id, 3, :hidden]
                     ], actions)
      else
        # if not excluded, this is a clean node
        assert_equal([], actions)
      end
    end
  end

  def test_whitelisted_node
    # Node 10 created and modified by disagreers, but creation is whitelisted
    # Node 11 created and modified by disagreers, but modification is whitelisted

    history = [OSM::Node[[0,0], :id => 10, :changeset => 3, :version => 1, "foo" => "bar"],
               OSM::Node[[1,1], :id => 10, :changeset => 3, :version => 2, "foo" => "bar", "abc" => "baz"]]

    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)

    assert_equal([Edit[OSM::Node[[0,0], :id => 10, :changeset => -1, :visible => true, :version => 2, "foo" => "bar"]],
                  Redact[OSM::Node, 10, 2, :hidden]], actions)

    history = [OSM::Node[[0,0], :id => 11, :changeset => 3, :version => 1, "foo" => "bar"],
               OSM::Node[[1,1], :id => 11, :changeset => 3, :version => 2, "foo" => "bar", "abc" => "baz"]]

    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)

    assert_equal([Edit[OSM::Node[[1,1], :id => 11, :changeset => -1, :visible => true, :version => 2, "abc" => "baz"]],
                  Redact[OSM::Node, 11, 1, :hidden],
                  Redact[OSM::Node, 11, 2, :visible]], actions)
  end

end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

