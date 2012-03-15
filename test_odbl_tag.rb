require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'test/unit'

class TestOdblTag < Test::Unit::TestCase
  def setup
    @db = DB.new(1 => Changeset[User[true]],
                 2 => Changeset[User[true]],
                 3 => Changeset[User[false]])
  end 

  # --------------------------------------------------------------------------
  # Tests concerning odbl=clean tag
  # --------------------------------------------------------------------------

  # odbl=clean overrides previous object history, but old versions still need to be redacted
  def test_node_odbl_clean
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "odbl" => "clean"]] # odbl=clean added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                 ], actions)
  end
  
  # as above, but with differently-cased odbl=clean tag
  def test_node_odbl_clean_case_insensitive
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "ODbL" => "Clean"]] # odbl=clean added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                 ], actions)
  end

  # Some people like to use "yes" instead of "clean"
  def test_node_odbl_clean_case_insensitive_yes
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "oDbL" => "yEs"]] # odbl=clean added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                 ], actions)
  end

  # Some people like to use "true" instead of "clean"
  def test_node_odbl_clean_case_insensitive_true
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "oDbL" => "TrUe"]] # odbl=clean added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                 ], actions)
  end

  # Some people like to use "1" instead of "clean"
  def test_node_odbl_clean_case_insensitive_one
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "oDbL" => "1"]] # odbl=clean added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                 ], actions)
  end
end
