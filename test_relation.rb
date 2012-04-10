require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'test/unit'

class TestRelation < Test::Unit::TestCase
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
  end 

  def test_relation_simple
    history = [OSM::Relation[
      [ [OSM::Way,1,""] , [OSM::Way,2,""] ],
      :id => 1,  :changeset => 3,  :version => 1,
      "type" => "route" ]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Delete[OSM::Relation, 1],
                  Redact[OSM::Relation, 1, 1, :hidden]
                 ], actions)
  end
  
  def test_relation_simple_keep
    history = [OSM::Relation[
      [ [OSM::Way,1,""] , [OSM::Way,2,""] ],
      :id => 1,  :changeset => 1,  :version => 1,
      "type" => "route" ]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions)
  end
  
  # relation created by decliner, then members added by agreer.
  # Under the v0 principle, we can keep the new members, but not the v1 members or the tags
  def test_relation_members_added
    history = [OSM::Relation[[ [OSM::Way,1] ,               [OSM::Way,2]               ], :id => 1,  :changeset => 3,  :version => 1, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,4], [OSM::Way,2]               ], :id => 1,  :changeset => 2,  :version => 2, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,4], [OSM::Way,2], [OSM::Way,3] ], :id => 1,  :changeset => 1,  :version => 3, "type" => "route" ]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,4], [OSM::Way,3] ], :id => 1,  :changeset => -1,  :version => 3]],
                  Redact[OSM::Relation, 1, 1, :hidden],
                  Redact[OSM::Relation, 1, 2, :visible],
                  Redact[OSM::Relation, 1, 3, :visible]
                 ], actions)
  end
  
  # relation members added by agreer, then role changed by decliner
  def test_relation_role_changed
    history = [OSM::Relation[[ [OSM::Way,1,"outer"] , [OSM::Way,2,""     ] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,"outer"] , [OSM::Way,2,"inner"] ], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1,"outer"] , [OSM::Way,2,""] ], :id=>1, :changeset=>-1, :version=>2, "type" => "multipolygon"]],
                  Redact[OSM::Relation,1,2,:hidden]
                 ], actions)
  end

  # relation members added by agreer, then role changed by decliner, and changed back by agreer. Intermediate edit should be redacted but no edits made.
  def test_relation_role_edited_reverted
    history = [OSM::Relation[[ [OSM::Way,1,"outer"] , [OSM::Way,2,"inner"] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,"outer"] , [OSM::Way,2,"aaaaa"] ], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,"outer"] , [OSM::Way,2,"inner"] ], :id=>1, :changeset=>1, :version=>3, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation,1,2,:hidden]], actions)
  end

  # relation member deleted by decliner. Way should be readded and deletion should be redacted.
  def test_relation_member_deleted_by_decliner
    history = [OSM::Relation[[ [OSM::Way,1,""] , [OSM::Way,2,""] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""] ], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1,""] , [OSM::Way,2,""] ], :id=>1, :changeset=>-1, :version=>2, "type" => "multipolygon"]], Redact[OSM::Relation,1,2,:hidden]], actions)
  end

  # relation member deleted by decliner then readded by agreer. The event should be redacted but no edits made.
  def test_relation_member_deleted_by_decliner_readded_by_agreer
    history = [OSM::Relation[[ [OSM::Way,1,""] , [OSM::Way,2,""] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""] ], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""] , [OSM::Way,2,""] ], :id=>1, :changeset=>1, :version=>3, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation,1,2,:hidden]], actions)
  end
  
end
