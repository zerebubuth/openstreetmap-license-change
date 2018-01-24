#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

class TestRelation < Minitest::Test
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
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,4], [OSM::Way,3] ], :id => 1,  :changeset => -1,  :version => 3, "type" => "route"]],
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

  # relation member deleted by decliner. by the "deletions are OK" rule, nothing needs to happen
  def test_relation_member_deleted_by_decliner
    history = [OSM::Relation[[ [OSM::Way,1,""] , [OSM::Way,2,""] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""] ], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions)
  end

  # relation member deleted by decliner then re-added by agreer. by the "deletions are OK" rule
  # there is no need to do anything to the element.
  def test_relation_member_deleted_by_decliner_readded_by_agreer
    history = [OSM::Relation[[ [OSM::Way,1,""] , [OSM::Way,2,""] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""] ], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""] , [OSM::Way,2,""] ], :id=>1, :changeset=>1, :version=>3, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions)
  end

  # relation attributes changed by decliner, then marked odbl=clean. Redact the original edit but make no edit to the final result.
  def test_relation_attributes_marked_clean
    history = [OSM::Relation[[ [OSM::Way,1,""]], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""]], :id=>1, :changeset=>3, :version=>2, "type" => "unipolygon"],
               OSM::Relation[[ [OSM::Way,1,""]], :id=>1, :changeset=>1, :version=>3, "type" => "unipolygon", "odbl" => "clean"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation,1,2,:hidden]], actions)
  end

  # member role changed by decliner, then marked odbl=clean. Redact the original edit but make no edit to the final result.
  def test_member_role_marked_clean
    history = [OSM::Relation[[ [OSM::Way,1,""]], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,"aaa"]], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,"aaa"]], :id=>1, :changeset=>1, :version=>3, "type" => "multipolygon", "odbl" => "clean"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation,1,2,:hidden]], actions)
  end

  # member role changed on way that subsequently gets deleted. Redact the change but make no edits.
  def test_relation_attribute_changed_then_deleted
    history = [OSM::Relation[[ [OSM::Way,1,""], [OSM::Way,2,""]], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""], [OSM::Way,2,"aaa"]], :id=>1, :changeset=>3, :version=>2, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1,""]], :id=>1, :changeset=>1, :version=>3, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation,1,2,:hidden]], actions)
  end

  # relation created by agreer, then order changed by decliner
  #
  # this is tricky for the same reason as the way-node ordering stuff above.
  # the change of order can equally be interpreted as a deletion and 
  # addition, which trigger a completely different set of rules.
  #
  def test_relation_order_changed
    history = [OSM::Relation[[ [OSM::Way,1] , [OSM::Way,4], [OSM::Way,2], [OSM::Way,3] ], :id => 1,  :changeset => 1,  :version => 1, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2], [OSM::Way,3], [OSM::Way,4] ], :id => 1,  :changeset => 3,  :version => 2, "type" => "route" ]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1], [OSM::Way,4], [OSM::Way,2], [OSM::Way,3] ], :id=>1, :changeset=>-1, :version=>2, "type" => "route"]],
                  Redact[OSM::Relation,1,2,:hidden]
                 ], actions)
  end
  
  # relation created by agreer, then order changed by decliner, then extra members added by agreer
  # (we can't preserve order in this case. Difficult to know what to do - fall back to the last 
  #  good order, with new members appended? Or try and insert at the same index, even if it doesn't
  #  make any sense without the previous order?)
  #
  # this is tricky for the same reason as the way-node ordering stuff above.
  # the change of order can equally be interpreted as a deletion and 
  # addition, which trigger a completely different set of rules.
  #
  def test_relation_order_changed_then_member_appended
    history = [OSM::Relation[[ [OSM::Way,1] , [OSM::Way,4], [OSM::Way,2], [OSM::Way,3]               ], :id => 1,  :changeset => 1,  :version => 1, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2], [OSM::Way,3], [OSM::Way,4]               ], :id => 1,  :changeset => 3,  :version => 2, "type" => "route" ],
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2], [OSM::Way,3], [OSM::Way,4], [OSM::Way,5] ], :id => 1,  :changeset => 2,  :version => 3, "type" => "route" ]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1], [OSM::Way,4], [OSM::Way,2], [OSM::Way,3], [OSM::Way,5] ], :id=>1, :changeset=>-1, :version=>3, "type" => "route"]],
                  Redact[OSM::Relation,1,2,:hidden],
                  Redact[OSM::Relation,1,3,:visible]
                 ], actions)
  end
  
  # simplified version of test_automatic_relation78000
  # member added by agreer in redacted changeset that is later removed by another agreer
  def test_relation_members_added_then_removed
    history = [OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2]                              ], :id => 1,  :changeset => 3,  :version => 1, "type" => "route" ], #decliner
               OSM::Relation[[                [OSM::Way,2], [OSM::Way,3] , [OSM::Way,4] ], :id => 1,  :changeset => 2,  :version => 2, "type" => "route" ], #agreer
               OSM::Relation[[                                             [OSM::Way,4] ], :id => 1,  :changeset => 1,  :version => 3, "type" => "route" ]] #agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation, 1, 1, :hidden],
                  Redact[OSM::Relation, 1, 2, :visible]
                 ], actions)
  end
  
  # member added as the first member by a decliner, that means that the member added in
  # the third version have to be inserted as first and not as seccond member
  def test_relation_members_added_by_decliner
    history = [OSM::Relation[[                               [OSM::Way,3] ], :id => 1,  :changeset => 1,  :version => 1 ], #agreer
               OSM::Relation[[ [OSM::Way,1] ,                [OSM::Way,3] ], :id => 1,  :changeset => 3,  :version => 2 ], #decliner
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2] , [OSM::Way,3] ], :id => 1,  :changeset => 2,  :version => 3 ]] #agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,2], [OSM::Way,3] ], :id => 1,  :changeset => -1,  :version => 3]],
                  Redact[OSM::Relation, 1, 2, :hidden],
                  Redact[OSM::Relation, 1, 3, :visible]
                 ], actions)
  end
  
  def test_relation_members_added_then_moved
    history = [OSM::Relation[[                [OSM::Way,2] , [OSM::Way,3] ], :id => 1,  :changeset => 1,  :version => 1 ], #agreer
               OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2] , [OSM::Way,3] ], :id => 1,  :changeset => 3,  :version => 2 ], #decliner
               OSM::Relation[[ [OSM::Way,3] , [OSM::Way,1] , [OSM::Way,2] ], :id => 1,  :changeset => 2,  :version => 3 ]] #agreer
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,3] , [OSM::Way,2] ], :id => 1,  :changeset => -1,  :version => 3]],
                  Redact[OSM::Relation, 1, 2, :hidden],
                  Redact[OSM::Relation, 1, 3, :visible]
                 ], actions)
  end

  # No error should be thrown when multipolyong members are of different classes.
  def test_sorting_multipolyon_members
    history = [OSM::Relation[[ [OSM::Way,1], [OSM::Node,2] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Node,2], [OSM::Way,1] ], :id=>1, :changeset=>2, :version=>2, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,1], [OSM::Node,2] ], :id=>1, :changeset=>3, :version=>3, "type" => "multipolygon"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([], actions)
  end

# Order should be important when the relation may not be a multipolygon
  def test_sorting_multipolyon_retag
    history = [OSM::Relation[[ [OSM::Way,1], [OSM::Way,2] ], :id=>1, :changeset=>1, :version=>1, "type" => "multipolygon"],
               OSM::Relation[[ [OSM::Way,2], [OSM::Way,1] ], :id=>1, :changeset=>3, :version=>2, "type" => "route"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1] , [OSM::Way,2] ], :id => 1,  :changeset => -1,  :version => 2, "type" => "multipolygon"]],
                  Redact[OSM::Relation, 1, 2, :hidden]
                 ], actions)
  end

  # Make sure that deletes does not mess with too much
  def test_relation_delete
    history = [OSM::Relation[[ [OSM::Way,1]               ], :id=>1, :changeset=>3, :version=>1],
               OSM::Relation[[                            ], :id=>1, :changeset=>1, :version=>2, :visible=>false],
               OSM::Relation[[ [OSM::Way,1], [OSM::Way,2] ], :id=>1, :changeset=>2, :version=>3],
               OSM::Relation[[ [OSM::Way,1]               ], :id=>1, :changeset=>3, :version=>4]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Redact[OSM::Relation, 1, 1, :hidden]
                 ], actions)
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

