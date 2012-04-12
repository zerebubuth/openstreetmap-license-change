require 'rubygems'
require 'minitest/unit'

require './test_node'
require './test_odbl_tag'
require './test_tags'
require './test_way'
require './test_relation'
require './test_util'
require './test_abbrev'
require './test_exceptions'
require './test_references'
require './test_auto'
require './test_needs_clarity'
require './test_auto_fail'

MiniTest::Unit.new.run(ARGV)

