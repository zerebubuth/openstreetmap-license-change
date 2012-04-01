require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'test/unit'

class TestRelation < Test::Unit::TestCase
  def setup
    @db = DB.new(1 => Changeset[User[true]],
                 2 => Changeset[User[true]],
                 3 => Changeset[User[false]])
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
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1,"outer"] , [OSM::Way,2,""] ], :id=>1, :changeset=>-1, :version=>3, "type" => "multipolygon"]],
                  Redact[OSM::Relation,1,2,:hidden]
                 ], actions)
  end
  
  # relation created by agreer, then order changed by decliner
  def test_relation_order_changed
    history = [OSM::Relation[[ [OSM::Way,1] , [OSM::Way,4], [OSM::Way,2], [OSM::Way,3] ], :id => 1,  :changeset => 1,  :version => 1, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2], [OSM::Way,3], [OSM::Way,4] ], :id => 1,  :changeset => 3,  :version => 2, "type" => "route" ]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1], [OSM::Way,4], [OSM::Way,2], [OSM::Way,3] ], :id=>1, :changeset=>-1, :version=>3, "type" => "route"]],
                  Redact[OSM::Relation,1,2,:hidden]
                 ], actions)
  end
  
  # relation created by agreer, then order changed by decliner, then extra members added by agreer
  # (we can't preserve order in this case. Difficult to know what to do - fall back to the last 
  #  good order, with new members appended? Or try and insert at the same index, even if it doesn't
  #  make any sense without the previous order?)
  def test_relation_order_changed_then_member_appended
    history = [OSM::Relation[[ [OSM::Way,1] , [OSM::Way,4], [OSM::Way,2], [OSM::Way,3]               ], :id => 1,  :changeset => 1,  :version => 1, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2], [OSM::Way,3], [OSM::Way,4]               ], :id => 1,  :changeset => 3,  :version => 2, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2], [OSM::Way,3], [OSM::Way,4], [OSM::Way,5] ], :id => 1,  :changeset => 2,  :version => 3, "type" => "route" ]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1], [OSM::Way,4], [OSM::Way,2], [OSM::Way,3], [OSM::Way,5] ], :id=>1, :changeset=>-1, :version=>4, "type" => "route"]],
                  Redact[OSM::Relation,1,2,:hidden],
                  Redact[OSM::Relation,1,3,:visible]
                 ], actions)
  end
end
