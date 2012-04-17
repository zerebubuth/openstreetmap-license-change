require 'rubygems'
require 'minitest/unit'

require './test_abbrev'
require './test_auto'
require './test_exceptions'
require './test_node'
require './test_odbl_tag'
require './test_references'
require './test_relation'
require './test_tags_lowlevel'
require './test_tags'
require './test_util'
require './test_way'
require './test_needs_clarity'
require './test_auto_fail'

MiniTest::Unit.new.run(ARGV)

