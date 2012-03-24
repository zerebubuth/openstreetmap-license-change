require 'rubygems'
require 'test/unit'

require './test_node'
require './test_odbl_tag'
require './test_tags'
require './test_way'
require './test_relation'
require './test_util'
require './test_abbrev'
require './test_needs_clarity'
require './test_exceptions.rb'

Test::Unit::Runner.new.run(ARGV)

