require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'test/unit'

class TestWay < Test::Unit::TestCase
  def setup
    @db = DB.new(1 => Changeset[User[true]],
                 2 => Changeset[User[true]],
                 3 => Changeset[User[false]])
  end 

  # --------------------------------------------------------------------------
  # Way tests
  # --------------------------------------------------------------------------

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
         
  # way created by decliner, but nodes subsequently replaced by agreer.
  # Under the v0 principle, we can keep the nodes, but not the tags
  def test_way_nodes_replaced
    history = [OSM::Way[[1,2,3], :id=>1, :changeset=>3, :version=>1, "highway"=>"primary"], # created by decliner
               OSM::Way[[4,6  ], :id=>1, :changeset=>1, :version=>2, "highway"=>"primary"]] # nodes replaced by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[4,6], :id=>1, :changeset=>-1, :version=>2]],
                  Redact[OSM::Way, 1, 1, :hidden],
                 ], actions)
  end

  # way created by agreer, but nodes removed by decliner, then subsequent edit by agreer
  def test_way_nodes_removed
    history = [OSM::Way[[1,2,3,4,5], :id=>1, :changeset=>1, :version=>1, "highway"=>"trunk"], # created by agreer
               OSM::Way[[1,2,  4,5], :id=>1, :changeset=>3, :version=>2, "highway"=>"trunk"], # node removed by decliner
               OSM::Way[[1,2,  4,5], :id=>1, :changeset=>2, :version=>3, "highway"=>"primary"]] # tag change by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3,4,5], :id=>1, :changeset=>-1, :version=>3, "highway"=>"primary"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                 ], actions)
  end

  # as above, but adding nodes
  def test_way_nodes_added
    history = [OSM::Way[[    1,2,3], :id=>1, :changeset=>1, :version=>1, "highway"=>"trunk"], # created by agreer
               OSM::Way[[4,5,1,2,3], :id=>1, :changeset=>3, :version=>2, "highway"=>"trunk"], # nodes added by decliner
               OSM::Way[[4,5,1,2,3], :id=>1, :changeset=>2, :version=>3, "highway"=>"primary"]] # tag change by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3], :id=>1, :changeset=>-1, :version=>3, "highway"=>"primary"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                 ], actions)
  end

  # as above, but replacing nodes and adding too
  # (where the node-list contains new agreeing IP (i.e. addition of nodes 5/6) and old declined IP (i.e. node 4),
  #  there's no simple solution but we should probably go by node ID)
  def test_way_nodes_replaced_and_added
    history = [OSM::Way[[1,2,3    ], :id=>1, :changeset=>1, :version=>1, "highway"=>"trunk"], # created by agreer
               OSM::Way[[1,4,3    ], :id=>1, :changeset=>3, :version=>2, "highway"=>"trunk"], # node removed by decliner
               OSM::Way[[1,4,3,5,6], :id=>1, :changeset=>2, :version=>3, "highway"=>"primary"]] # tag change and node addition by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3,5,6], :id=>1, :changeset=>-1, :version=>3, "highway"=>"primary"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                 ], actions)
  end

  # ** FIXME: add some more way tests here, and some relation ones too.

  # --------------------------------------------------------------------------
  # Way tests
  # --------------------------------------------------------------------------

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
         
  # way created by decliner, but nodes subsequently replaced by agreer.
  # Under the v0 principle, we can keep the nodes, but not the tags
  def test_way_nodes_replaced
    history = [OSM::Way[[1,2,3], :id=>1, :changeset=>3, :version=>1, "highway"=>"primary"], # created by decliner
               OSM::Way[[4,6  ], :id=>1, :changeset=>1, :version=>2, "highway"=>"primary"]] # nodes replaced by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[4,6], :id=>1, :changeset=>-1, :version=>2]],
                  Redact[OSM::Way, 1, 1, :hidden],
                 ], actions)
  end

  # way created by agreer, but nodes removed by decliner, then subsequent edit by agreer
  def test_way_nodes_removed
    history = [OSM::Way[[1,2,3,4,5], :id=>1, :changeset=>1, :version=>1, "highway"=>"trunk"], # created by agreer
               OSM::Way[[1,2,  4,5], :id=>1, :changeset=>3, :version=>2, "highway"=>"trunk"], # node removed by decliner
               OSM::Way[[1,2,  4,5], :id=>1, :changeset=>2, :version=>3, "highway"=>"primary"]] # tag change by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3,4,5], :id=>1, :changeset=>-1, :version=>3, "highway"=>"primary"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                 ], actions)
  end

  # as above, but adding nodes
  def test_way_nodes_added
    history = [OSM::Way[[    1,2,3], :id=>1, :changeset=>1, :version=>1, "highway"=>"trunk"], # created by agreer
               OSM::Way[[4,5,1,2,3], :id=>1, :changeset=>3, :version=>2, "highway"=>"trunk"], # nodes added by decliner
               OSM::Way[[4,5,1,2,3], :id=>1, :changeset=>2, :version=>3, "highway"=>"primary"]] # tag change by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3], :id=>1, :changeset=>-1, :version=>3, "highway"=>"primary"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                 ], actions)
  end

  # as above, but replacing nodes and adding too
  # (where the node-list contains new agreeing IP (i.e. addition of nodes 5/6) and old declined IP (i.e. node 4),
  #  there's no simple solution but we should probably go by node ID)
  def test_way_nodes_replaced_and_added
    history = [OSM::Way[[1,2,3    ], :id=>1, :changeset=>1, :version=>1, "highway"=>"trunk"], # created by agreer
               OSM::Way[[1,4,3    ], :id=>1, :changeset=>3, :version=>2, "highway"=>"trunk"], # node removed by decliner
               OSM::Way[[1,4,3,5,6], :id=>1, :changeset=>2, :version=>3, "highway"=>"primary"]] # tag change and node addition by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[1,2,3,5,6], :id=>1, :changeset=>-1, :version=>3, "highway"=>"primary"]],
                  Redact[OSM::Way, 1, 2, :hidden],
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
         
  # if an acceptor creates a way, a decliner adds some nodes but doesn't
  # change the tags in a subsequent edit, then we just need to roll back
  # the nodes changes.
  def test_way_decliner_adds_nodes
    # test multiple versions of this - it shouldn't matter where in the
    # way the decliner has added the nodes.
    init_nodes = [1,2,3]
    edit_nodes = [[4,5,6,1,2,3],
                  [4,1,5,2,6,3],
                  [1,4,2,5,3,6],
                  [1,2,4,5,6,3],
                  [1,2,3,4,5,6]]
    edit_nodes.each do |next_nodes|
      history = [OSM::Way[init_nodes, :id => 1, :changeset => 1, :version => 1, "highway" => "trunk"],
                 OSM::Way[next_nodes, :id => 1, :changeset => 3, :version => 2, "highway" => "trunk"]]
      bot = ChangeBot.new(@db)
      actions = bot.action_for(history)
      assert_equal([Edit[OSM::Way[init_nodes, :id => 1, :changeset => -1, :version => 2, "highway" => "trunk"]],
                    Redact[OSM::Way, 1, 2, :hidden]
                   ], actions)
    end
  end

  # by the "version zero" proposal, a way at version zero has an empty
  # list of nodes, so even if the way was created by a decliner, the 
  # addition of nodes to it by an acceptor is salvagable. note, however
  # that the tags are not.
  def test_way_decliner_creates_acceptor_adds
    history = [OSM::Way[[1,2,3],       :id => 1, :changeset => 3, :version => 1, "highway" => "trunk"],
               OSM::Way[[1,2,4,3,5,6], :id => 1, :changeset => 1, :version => 2, "highway" => "trunk", "ref" => "666"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[4,5,6], :id => 1, :changeset => -1, :version => 2, "ref" => "666"]],
                  Redact[OSM::Way, 1, 1, :hidden],
                  Redact[OSM::Way, 1, 2, :visible]
                 ], actions)
  end    

  # a variant of the above, in which the way is created by an acceptor,
  # but all of the nodes are replaced in the second version by a decliner.
  # however, tags created in the first, acceptor, version are clean.
  def test_way_decliner_sandwich_replace
    history = [OSM::Way[[7,8,9],       :id => 1, :changeset => 1, :version => 1, "highway" => "trunk"],
               OSM::Way[[1,2,3],       :id => 1, :changeset => 3, :version => 2, "highway" => "trunk"],
               OSM::Way[[1,2,4,3,5,6], :id => 1, :changeset => 1, :version => 3, "highway" => "trunk", "ref" => "666"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Way[[4,5,6], :id => 1, :changeset => -1, :version => 3, "highway" => "trunk", "ref" => "666"]],
                  Redact[OSM::Way, 1, 2, :hidden],
                  Redact[OSM::Way, 1, 3, :visible]
                 ], actions)
  end    

  # ** FIXME: add some more way tests here, and some relation ones too.
end
