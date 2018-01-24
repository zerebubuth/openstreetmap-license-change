#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

# Tests related to how redactions are applied to way edits.
class TestWay < Minitest::Test
  def setup
    @db = DB.new(changesets: {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
  end

  # --------------------------------------------------------------------------
  # Way tests
  # --------------------------------------------------------------------------

  # way created by decliner, with no other edits, needs to be deleted
  # and redacted hidden.
  def test_way_simple
    history = [OSM::Way[[1, 2, 3], id: 1, changeset: 3, version: 1]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Way, 1],
                  Redact[OSM::Way, 1, 1, :hidden]], actions)
  end

  # way created by decliner, but nodes subsequently replaced by agreer.
  # Under the v0 principle, we can keep the nodes, but not the tags
  def test_way_nodes_replaced
    history = [OSM::Way[[1, 2, 3], :id => 1, :changeset => 3, :version => 1, 'highway' => 'primary'], # created by decliner
               OSM::Way[[4, 6], :id => 1, :changeset => 1, :version => 2, 'highway' => 'primary']] # nodes replaced by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[4, 6], id: 1, changeset: -1, version: 2]],
                  Redact[OSM::Way, 1, 1, :hidden],
                  Redact[OSM::Way, 1, 2, :visible]], # this version has the tainted highway tag in it
                 actions)
  end

  # way created by decliner, but nodes subsequently replaced by agreer.
  # Under the v0 principle, we can keep the nodes
  def test_way_nodes_replaced_no_tag
    history = [OSM::Way[[1, 2, 3], id: 1, changeset: 3, version: 1], # created by decliner
               OSM::Way[[4, 6], id: 1, changeset: 1, version: 2]] # nodes replaced by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Way, 1, 1, :hidden]], actions)
  end

  # way created by agreer, but nodes removed by decliner, then subsequent edit by agreer
  def test_way_nodes_removed
    history = [OSM::Way[[1, 2, 3, 4, 5], :id => 1, :changeset => 1, :version => 1, 'highway' => 'trunk'], # created by agreer
               OSM::Way[[1, 2,  4, 5], :id => 1, :changeset => 3, :version => 2, 'highway' => 'trunk'], # node removed by decliner
               OSM::Way[[1, 2,  4, 5], :id => 1, :changeset => 2, :version => 3, 'highway' => 'primary']] # tag change by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    # by the "deletes are OK" rule, the deletion of node 3 is OK to keep.
    assert_equal([], actions)
  end

  # as above, but adding nodes
  def test_way_nodes_added
    history = [OSM::Way[[1, 2, 3], :id => 1, :changeset => 1, :version => 1, 'highway' => 'trunk'], # created by agreer
               OSM::Way[[4, 5, 1, 2, 3], :id => 1, :changeset => 3, :version => 2, 'highway' => 'trunk'], # nodes added by decliner
               OSM::Way[[4, 5, 1, 2, 3], :id => 1, :changeset => 2, :version => 3, 'highway' => 'primary']] # tag change by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1, 2, 3], :id => 1, :changeset => -1, :version => 3, 'highway' => 'primary']],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]], # needs to be redacted, as nodes [4,5] are still in this version
                 actions)
  end

  # if an acceptor creates a way, a decliner adds some nodes but doesn't
  # change the tags in a subsequent edit, then we just need to roll back
  # the nodes changes.
  def test_way_decliner_adds_nodes
    # test multiple versions of this - it shouldn't matter where in the
    # way the decliner has added the nodes.
    init_nodes = [1, 2, 3]
    edit_nodes = [[4, 5, 6, 1, 2, 3],
                  [4, 1, 5, 2, 6, 3],
                  [1, 4, 2, 5, 3, 6],
                  [1, 2, 4, 5, 6, 3],
                  [1, 2, 3, 4, 5, 6]]
    edit_nodes.each do |next_nodes|
      history = [OSM::Way[init_nodes, :id => 1, :changeset => 1, :version => 1, 'highway' => 'trunk'],
                 OSM::Way[next_nodes, :id => 1, :changeset => 3, :version => 2, 'highway' => 'trunk']]
      bot = ChangeBot.new(@db)
      actions = bot.action_for(history)
      assert_equal([Edit[OSM::Way[init_nodes, :id => 1, :changeset => -1, :version => 2, 'highway' => 'trunk']],
                    Redact[OSM::Way, 1, 2, :hidden]], actions)
    end
  end

  # by the "version zero" proposal, a way at version zero has an empty
  # list of nodes, so even if the way was created by a decliner, the
  # addition of nodes to it by an acceptor is salvagable. note, however
  # that the tags are not.
  def test_way_decliner_creates_acceptor_adds
    history = [OSM::Way[[1, 2, 3], :id => 1, :changeset => 3, :version => 1, 'highway' => 'trunk'],
               OSM::Way[[1, 2, 4, 3, 5, 6], :id => 1, :changeset => 1, :version => 2, 'highway' => 'trunk', 'ref' => '666']]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[4, 5, 6], :id => 1, :changeset => -1, :version => 2, 'ref' => '666']],
                  Redact[OSM::Way, 1, 1, :hidden],
                  Redact[OSM::Way, 1, 2, :visible]], actions)
  end

  # a variant of the above, in which the way is created by an acceptor,
  # but all of the nodes are replaced in the second version by a decliner.
  # however, tags created in the first, acceptor, version are clean.
  def test_way_decliner_sandwich_replace
    history = [OSM::Way[[7, 8, 9],       :id => 1, :changeset => 1, :version => 1, 'highway' => 'trunk'],
               OSM::Way[[1, 2, 3],       :id => 1, :changeset => 3, :version => 2, 'highway' => 'trunk'],
               OSM::Way[[1, 2, 4, 3, 5, 6], :id => 1, :changeset => 1, :version => 3, 'highway' => 'trunk', 'ref' => '666']]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[4, 5, 6], :id => 1, :changeset => -1, :version => 3, 'highway' => 'trunk', 'ref' => '666']],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]], actions)
  end

  # test what happens when way nodes are deleted and added.
  #
  # upon careful consideration, we reckoned that deletions of way nodes should stay
  # deleted as the most likely case for losing a node from a way is that it was
  # also deleted, so adding it back would probably serve no purpose. with that in
  # mind, node replacements should be treated as a deletion followed by an addition
  # and, if the addition is by a decliner, should be removed from the final version.
  #
  def test_way_nodes_replaced_and_added
    history = [OSM::Way[[1, 2, 3], :id => 1, :changeset => 1, :version => 1, 'highway' => 'trunk'], # created by agreer
               OSM::Way[[1, 4, 3], :id => 1, :changeset => 3, :version => 2, 'highway' => 'trunk'], # node removed by decliner
               OSM::Way[[1, 4, 3, 5, 6], :id => 1, :changeset => 2, :version => 3, 'highway' => 'primary']] # tag change and node addition by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1, 3, 5, 6], :id => 1, :changeset => -1, :version => 3, 'highway' => 'primary']],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]], # needs to be redacted - node 4 still in this version
                 actions)
  end

  # Non-agreeing user updates created_by tag and deletes note
  def test_auto_tag_change_and_tag_deletion
    history = [OSM::Way[[1, 2, 3], :id => 1, :version => 1, :changeset => 1, 'created_by' => 'Potlatch 0.5c', 'note' => 'B-flat'], # agreed,
               OSM::Way[[1, 2, 3], :id => 1, :version => 2, :changeset => 3, 'created_by' => 'Potlatch 0.8c']] # not agreed,
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions)
  end

  # test simplified from auto-generated test for way 4890000
  # v1 is decliner but agreer adds a single node in v2. This could be kept but results in a single-node way so should be deleted.
  def test_one_node_way_outcome
    history = [OSM::Way[[1, 2, 3], :id => 1, :version => 1, :visible => true, :changeset => 3, 'a' => 'b'], # not agreed,
               OSM::Way[[1, 2, 3, 4], :id => 1, :version => 2, :visible => true, :changeset => 1, 'a' => 'b']] # agreed
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Way, 1], # only one node would remain so delete
                  Redact[OSM::Way, 1, 1, :hidden],
                  Redact[OSM::Way, 1, 2, :visible]], actions)
  end

  # test as proposed by Spod (http://lists.openstreetmap.org/pipermail/rebuild/2012-April/000221.html)
  # created by decliner, all tags completely changed by agreer
  def test_way_all_tags_changed
    history = [OSM::Way[[1, 2, 3], :id => 1, :version => 1, :visible => true, :changeset => 3, 'name' => 'Westgate', 'highway' => 'secondary'], # not agreed,
               OSM::Way[[4, 5, 6], :id => 1, :version => 2, :visible => true, :changeset => 1, 'name' => 'Sheffield Road', 'highway' => 'tertiary']] # agreed
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Way, 1, 1, :hidden]], actions)
  end

  def test_way_nodes_added_first
    history = [OSM::Way[[3], id: 1, changeset: 1, version: 1], # created by agreer
               OSM::Way[[1,  3], id: 1, changeset: 3, version: 2], # node added to the front by decliner
               OSM::Way[[1, 2, 3], id: 1, changeset: 2, version: 3]] # node addition by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[2, 3], id: 1, changeset: -1, version: 3]],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]], actions)
  end

  def test_way_nodes_added_and_reversed
    history = [OSM::Way[[1, 2], id: 1, changeset: 1, version: 1], # created by agreer
               OSM::Way[[1, 2, 3], id: 1, changeset: 3, version: 2], # node added by decliner
               OSM::Way[[3, 2, 1], id: 1, changeset: 2, version: 3]] # way reversed by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[2, 1], id: 1, changeset: -1, version: 3]],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]], actions)
  end

  def test_way_reversed_by_decliner
    history = [OSM::Way[[1, 2], :id => 1, :changeset => 1, :version => 1, 'oneway' => '-1'], # created by agreer
               OSM::Way[[2, 1], :id => 1, :changeset => 3, :version => 2, 'oneway' => 'yes'], # way reversed by decliner
               OSM::Way[[3, 2, 1], :id => 1, :changeset => 2, :version => 3, 'oneway' => 'yes']] # node added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1, 2, 3], :id => 1, :changeset => -1, :version => 3, 'oneway' => '-1']],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]], actions)
  end

  def test_way_nodes_added_and_moved
    history = [OSM::Way[[1, 3], id: 1, changeset: 1, version: 1], # created by agreer
               OSM::Way[[1, 2, 3], id: 1, changeset: 3, version: 2], # node added by decliner
               OSM::Way[[2, 1, 3], id: 1, changeset: 2, version: 3]] # node moved by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1, 3], id: 1, changeset: -1, version: 3]],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]], actions)
  end

  def test_way_nodes_added_and_moved2
    history = [OSM::Way[[1, 3], id: 1, changeset: 3, version: 1], # created by decliner
               OSM::Way[[1, 2, 3, 4], id: 1, changeset: 1, version: 2], # node added by agreer
               OSM::Way[[3, 1, 2, 4], id: 1, changeset: 2, version: 3]] # node moved by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[2, 4], id: 1, changeset: -1, version: 3]],
                  Redact[OSM::Way, 1, 1, :hidden],
                  Redact[OSM::Way, 1, 2, :visible],
                  Redact[OSM::Way, 1, 3, :visible]], actions)
  end
end

MiniTest::Unit.new.run(ARGV) if $PROGRAM_NAME == __FILE__
