#!/usr/bin/env ruby
# encoding: UTF-8

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

class TestTags < Minitest::Test
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
  end 

  # --------------------------------------------------------------------------
  # Tests concerned with the keeping and removing of tags. 
  # --------------------------------------------------------------------------

  # This tests the following scenario:
  # * agreer creates object
  # * decliner adds a name tag
  # * agreer makes a trivial change to that tag
  # * therefore the decliner retains "ownership" and the tag must be 
  #   removed.

  def test_trivial_name_change_by_agreer

    trivialchanges = {
        "Oxford St" => "Oxford Street", 
        "Johnann Wolfgang von Goethe Allee" => "Johann-Wolfgang-von-Goethe-Allee",
        "Mulberry Hiway" => "Mulberry Highway",
        "old fen way" => "Old Fen Way",
        "Lodnon" => "London",
        "strasse" => "Straße",
        "Supercalifragilisticexpialidocious Stret" => "Supercalifragilisticexpialidocious Street"
    }

    trivialchanges.each do | old, new |
      assert_equal(false, Tags.significant_tag?(old, new), "#{old.inspect} -> #{new.inspect} not considered trivial.")

        history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1], 
                   OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2,
                             "name" => old],
                   OSM::Node[[0,0], :id => 1, :changeset => 2, :version => 3, 
                             "name" => new]]

        bot = ChangeBot.new(@db)
        actions = bot.action_for(history)

        assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 3]],
                      Redact[OSM::Node, 1, 2, :hidden],
                      Redact[OSM::Node, 1, 3, :visible],
                     ], actions)
    end
  end

  # This is the reverse of trivial_name_change_by_agreer:
  # * agreer creates object
  # * agreer adds a name tag
  # * decliner makes a trivial change to that tag
  # * therefore the agreer retains "ownership" and the tag can be retained.
  # (the assumption here is that the trvial change is not deserving
  # of copyright or any other protection - that it could be done by 
  # an automated process)

  def test_trivial_name_change_by_decliner
    trivial_changes = { 
      "Oxford St" => "Oxford Street", 
      "Johnann Wolfgang von Goethe Allee" => "Johann-Wolfgang-von-Goethe-Allee",
      "Mulberry Hiway" => "Mulberry Highway",
      "old fen way" => "Old Fen Way",
      "Lodnon" => "London",
      "strasse" => "Straße",
      "Supercalifragilisticexpialidocious Stret" => "Supercalifragilisticexpialidocious Street"
    }

    trivial_changes.each do |old, new|
      assert_equal(false, Tags.significant_tag?(old, new), "#{old.inspect} -> #{new.inspect} not considered trivial.")
      expect_redaction([], # expect no redactions here...
                       [[true,  {}],
                        [true, {"name" => old}],
                        [false,  {"name" => new}]
                       ])
    end
  end

  # Scenario:
  # * agreer creates object
  # * agreer adds a tag
  # * decliner makes a trivial change to the key, keeping the value the same
  # as before, the trivial change is not deserving of protection, so the
  # change will be kept.
  def test_trivial_key_change_by_decliner
    trivial_changes = {
      "nmae" => "name",
      "addr:hosenumber"  => "addr:housenumber",
      "addr_housenumber" => "addr:housenumber",
      "addr:housenummer" => "addr:housenumber"
    }

    trivial_changes.each do |old, new|
      assert_equal(false, Tags.significant_tag?(old, new), "#{old.inspect} -> #{new.inspect} not considered trivial.")
      expect_redaction([],
                       [[true,  {}],
                        [true, {old => "some value here"}],
                        [false,  {new => "some value here"}]
                       ])
    end
  end

  # This tests the following scenario:
  # * agreer creates object
  # * decliner adds a name tag
  # * agreer makes a significant change to that tag
  # * therefore the decliner's change must be rolled back.

  def test_significant_name_change_by_decliner
    significant_changes = { 
      "Oxford St" => "Bedford St",
      "Johnann Wolfgang von Goethe Allee" => "Johann-Sebastian-Bach-Allee",
      "Mulberry Hiway" => "Blueberry Valley Drive",
      "улица Интернацион" => "улица Бешенковичи",
    }

    significant_changes.each do |old, new|
      # check that the method considers them actually significant first...
      assert_equal(true, Tags.significant_tag?(old, new), "#{old.inspect} -> #{new.inspect} not considered significant.")
      expect_redaction([[2, :hidden]],
                       [[true,  {}],
                        [false, {"name" => old}],
                        [true,  {"name" => new}]
                       ])
    end      
  end

  # This tests the following scenario:
  # * agreer creates object
  # * agreer adds a name tag
  # * decliner makes a significant change to that tag
  # * therefore the tag must be rolled back to before the significant change

  def test_significant_name_change_by_agreer
    
    significantchanges = { 
      "Oxford St" => "Bedford St",
      "Johnann Wolfgang von Goethe Allee" => "Johann-Sebastian-Bach-Allee",
      "Mulberry Hiway" => "Blueberry Valley Drive",
      "Wellington Avenue" => "Wellington Way",
    }
    
    significantchanges.each do | old, new |
      assert_equal(true, Tags.significant_tag?(old, new), "#{old.inspect} -> #{new.inspect} not considered significant.")
      
      history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1], 
                 OSM::Node[[0,0], :id => 1, :changeset => 2, :version => 2,
                           "name" => old],
                 OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 3, 
                           "name" => new]]
      
      bot = ChangeBot.new(@db)
      actions = bot.action_for(history)
      
      # decliner's version hidden but no change to object
      assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 3, "name" => old]],
                    Redact[OSM::Node, 1, 3, :hidden]
                   ], actions)
    end
  end
  
  # This tests the following scenario:
  # * agreer creates object
  # * decliner adds a ref tag
  # * agreer makes a trivial change to that tag
  # * therefore the decliner retains "ownership" and the tag must be 
  #   removed.

  def test_trivial_ref_change_by_agreer

    trivialchanges = {
        "E16" => "E 16", 
        "1;R5" => "R1;R5",  # This fails, probably because 1 char is a high % of a short string
        "1;R5;R6" => "R1;R5;R6",    # This passes
        "Rv7" => "RV7"
    }

    trivialchanges.each do | old, new |
      assert_equal(false, Tags.significant_tag?(old, new), "#{old.inspect} -> #{new.inspect} not considered trivial.")

        history = [OSM::Node[[0,0], :id => 1, :changeset => 1, :version => 1], 
                   OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2,
                             "ref" => old],
                   OSM::Node[[0,0], :id => 1, :changeset => 2, :version => 3, 
                             "ref" => new]]

        bot = ChangeBot.new(@db)
        actions = bot.action_for(history)

        assert_equal([Edit[OSM::Node[[0,0], :id => 1, :changeset => -1, :version => 3]],
                      Redact[OSM::Node, 1, 2, :hidden],
                      Redact[OSM::Node, 1, 3, :visible],
                     ], actions)
    end
  end

  private
  
  def expect_redaction(redacts, tags)
    history = Array.new

    tags.each_with_index do |e, version|
      agreer_edit, t = e
      hash = { :id => 1, :changeset => (agreer_edit ? 1 : 3), :version => (version + 1) }
      hash.merge!(t)
      history << OSM::Node[[0, 0], hash]
    end

    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)

    assert_equal(redacts.map {|v,h| Redact[OSM::Node, 1, v, h]}, actions, 
                 "Note: with tag pattern #{tags}")
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

