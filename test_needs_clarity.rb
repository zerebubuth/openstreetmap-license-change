#!/usr/bin/env ruby

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require 'minitest/unit'

############################################################
#
# NOTE: the tests here have been put here because someone
# needs to have a serious think about what the result of 
# the license change should be on these cases. please see
# the comments before and inside the tests for more 
# details.
#
############################################################

class TestNeedsClarity < MiniTest::Unit::TestCase
  def setup
    @db = DB.new(:changesets => {
                   1 => Changeset[User[true]],
                   2 => Changeset[User[true]],
                   3 => Changeset[User[false]]
                 })
  end 

    # this is a node with some early bad content all of which has been eradicated many versions ago
    # It also has an old tag mapped by a problem mapper reintroduced later by an agreeing mapper.
    # LWG has clarified that such reintroductions are clean _if_ they happen in a separate changeset
    # to the removal of the tag. (that is, tax is put back in a separate context, we apply good faith in the agreeing mapper)
    #
    # NOTE: this needs some thought.
    # the issue is that the "foo=bar" tag re-added in v9 is the same as a tag added by
    # a decliner in v1. on the basis of identity it might be hard to tell whether this
    # is newly-surveyed data, or added by looking at the object's history. 
    #
    # so the question is: can a tag added by an agreer in a later version of an element, 
    # even though it may be similar to a previously-removed tag added by a decliner, be 
    # considered clean?
    #
    def test_node_reformed_ccoholic
        history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"], # created by decliner
        OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2 ], # tag removed by decliner
        OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 3, "sugar" => "sweet" ], # tag added by decliner
        OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 4, "sugar" => "sweet", "bar" => "baz"], # other tag added, node moved by agreer
        OSM::Node[[1,1], :id => 1, :changeset => 3, :version => 5, "sugar" => "sweet", "rose" => "red", "bar" => "baz" ], # tag added by decliner
        OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 6, "sugar" => "sweet", "bar" => "baz", "dapper" => "mapper" ], # tag added by agreer, dirty tag removed
        OSM::Node[[2,2], :id => 1, :changeset => 1, :version => 7, "bar" => "baz", "dapper" => "mapper" ], # moved by agreer  
        OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 8, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2" ], # tag added by agreer
        OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "foo" => "bar" ]] # tag re-added by agreer
        bot = ChangeBot.new(@db)
        actions = bot.action_for(history)
        # this is effectively a revert back to version 8 (because v9 re-adds the tainted "foo=bar" tag)
        #                                                 ^^^^^^^^^^^^^^^^^^^^^^ -- this needs more thought
        # and then hides version 6 and before because v6-v3 have the "sugar=sweet" tag which was added
        # by a decliner and is therefore tainted, and v1 & v2 are decliner edits.
        assert_equal([Redact[OSM::Node, 1, 1, :hidden],
                     Redact[OSM::Node, 1, 2, :hidden],
                     Redact[OSM::Node, 1, 3, :hidden],
                     Redact[OSM::Node, 1, 4, :visible],
                     Redact[OSM::Node, 1, 5, :hidden],
                     Redact[OSM::Node, 1, 6, :visible],
                     ], actions)
    end
    
    # Identical to test_node_reformed_ccoholic but the tag is reintroduced in the same change set as it is deleted
    # LWG has concluded that this may be risky and would prefer to see odbl=clean used in such cases with no tag deletion and replacement

    def test_node_reformed_ccoholic_too_hasty
        history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "foo" => "bar"], # created by decliner
        OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 2, "foo" => "bar", "diddle" => "dum" ], # tag added by decliner
        OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 3, "foo" => "bar", "diddle" => "dum", "sugar" => "sweet" ], # tag added by decliner
        OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 4, "foo" => "bar", "diddle" => "dum", "sugar" => "sweet", "bar" => "baz"], # other tag added, node moved by agreer
        OSM::Node[[1,1], :id => 1, :changeset => 3, :version => 5, "foo" => "bar", "diddle" => "dum", "sugar" => "sweet", "bar" => "baz", "sugar" => "sweet", "rose" => "red"], # tag added by decliner
        OSM::Node[[1,1], :id => 1, :changeset => 2, :version => 6, "bar" => "baz", "dapper" => "mapper" ], # tag added by agreer, dirty tags removed
        OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 7, "bar" => "baz", "dapper" => "mapper", "foo" => "bar"], # Previously dirty tag added back in **same changeset as deletion**  
        OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 8, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "foo" => "bar" ], # tag added by agreer
        OSM::Node[[2,2], :id => 1, :changeset => 2, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "foo" => "bar", "bored" => "yet?" ]] # new tag added by agreer
        bot = ChangeBot.new(@db)
        actions = bot.action_for(history)
       
        assert_equal([Edit[OSM::Node[[2,2], :id => 1, :changeset => -1, :version => 9, "bar" => "baz", "dapper" => "mapper", "e" => "mc**2", "bored" => "yet?" ]],
                     Redact[OSM::Node, 1, 1, :hidden],
                     Redact[OSM::Node, 1, 2, :hidden],
                     Redact[OSM::Node, 1, 3, :hidden],
                     Redact[OSM::Node, 1, 4, :visible],
                     Redact[OSM::Node, 1, 5, :hidden],
                     #         Redact[OSM::Node, 1, 6, :visible],   # Surely this version is clean and needs no redaction?
                     Redact[OSM::Node, 1, 7, :visible],
                     Redact[OSM::Node, 1, 8, :visible],
                     Redact[OSM::Node, 1, 9, :visible],
                     ], actions)
    end
    
  # We can even keep (some...) changes to a tag created by a non-agreeing mapper
  #
  # NOTE: needs some thought.
  # the issue here is whether the *keys* of tags contain any copyright status.
  # here, the key is changed from "foo"="bar" to "foo"="feefie", which is a 
  # Significant Change to the value (see tests for that in test_tags.rb), but
  # is no change to the key. 
  #
  # if we assume that keys are potentially copyrightable then we must reject
  # the following test case, and potentially leave a lot of "highway"= and 
  # "name"= tags in an old state (or remove them). on the other hand, some
  # tags may well have copyright-worthy information in the keys, given that
  # they're free-form strings just like the values.
  def test_simple_node_unclean_edited_clean_later_position_bad_tag_changed
    history = [OSM::Node[[0,0], :id => 1, :changeset => 3, :version => 1, "wibble" => "wobble", "foo" => "bar"],
               OSM::Node[[1,1], :id => 1, :changeset => 1, :version => 2, "wibble" => "wobble", "foo" => "feefie"]]
    bot = ChangeBot.new(@db)
    actions = bot.action_for(history)
    assert_equal([Edit[OSM::Node[[1,1], :id => 1, :changeset => -1, :version => 2, "foo" => "feefie"]], 
                  Redact[OSM::Node, 1, 1, :hidden], 
                  Redact[OSM::Node, 1, 2, :visible]
                 ], actions)
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
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1], [OSM::Way,4], [OSM::Way,2], [OSM::Way,3] ], :id=>1, :changeset=>-1, :version=>3, "type" => "route"]],
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
    assert_equal([Edit[OSM::Relation[[ [OSM::Way,1], [OSM::Way,4], [OSM::Way,2], [OSM::Way,3], [OSM::Way,5] ], :id=>1, :changeset=>-1, :version=>4, "type" => "route"]],
                  Redact[OSM::Relation,1,2,:hidden],
                  Redact[OSM::Relation,1,3,:visible]
                 ], actions)
  end

end
