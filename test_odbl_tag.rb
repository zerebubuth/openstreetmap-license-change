#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

class TestOdblTag < Minitest::Test
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
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
  
  # Some people like to use "clear" instead of "clean"
  def test_node_odbl_clean_case_insensitive_clear
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "odbl" => "clear"]] # odbl=clean added by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                 ], actions)
  end
    
    
    # Cater for the typo obdl=clean
    def test_node_obdl_clean
        history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
        OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
        OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "obdl" => "clean"]] # obdl=clean (typo) added by agreer
        bot = ChangeBot.new(@db)
        actions = bot.action_for(history)
        assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                     ], actions)
    end
    
  # Cater for the typo obdl=clean
  def test_node_obdl_clean_typo
      history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
      OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
      OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "oodbl" => "clean"]] # obdl=clean (typo) added by agreer
      bot = ChangeBot.new(@db)
      actions = bot.action_for(history)
      assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                   ], actions)
  end
    
  # What happenes when the odbl=clean is removed
  def test_node_odbl_clean_removed
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "odbl" => "clean"], # odbl=clean added by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 4, "foo" => "bar"]] # tag removed by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[0, 0], :id => 1, :version => 4, :visible => true, :changeset => -1]],
                  Redact[OSM::Node, 1, 2, :hidden],
                  Redact[OSM::Node, 1, 3, :visible],
                  Redact[OSM::Node, 1, 4, :visible]
                 ], actions)
  end
  
  # What if someone was adding and removing the odbl=clean tag
  def test_node_odbl_clean_removed
    history = [OSM::Node[[0,0], :id=>1, :changeset => 1, :version => 1], # created by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 3, :version => 2, "foo" => "bar"], # edited by decliner
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 3, "foo" => "bar", "odbl" => "clean"], # odbl=clean added by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 4, "foo" => "bar"], # odbl tag removed by agreer
               OSM::Node[[0,0], :id=>1, :changeset => 2, :version => 5, "odbl" => "clean"]] # object cleaned and odbl tag reintroduced by agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Node, 1, 2, :hidden],
                  Redact[OSM::Node, 1, 3, :visible],
                  Redact[OSM::Node, 1, 4, :visible]
                 ], actions)
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

