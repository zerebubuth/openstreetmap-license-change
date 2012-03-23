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
end
