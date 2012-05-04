#!/usr/bin/env ruby
# encoding: UTF-8

require './change_bot'
require './user'
require './changeset'
require './db'
require './actions'
require './util.rb'
require './abbreviations.rb'
require 'minitest/unit'

class TestAbbrev < MiniTest::Unit::TestCase

  # test that some strings are the same under abbreviation, 
  # even when there's differing whitespace or punctuation
  # involved.
  def test_abbrev
    check_abbrev_equality("Foobar Rd", "Foobar Road")
    check_abbrev_equality("Foobar Road", "Foobar Rd")
    check_abbrev_equality("E Foobar Wy", "East Foobar Way")
    check_abbrev_equality("NE Foobar Crescent", "North East Foobar Cr.")
    check_abbrev_equality("N.E. Foobar Crescent", "North East Foobar Cr")
    check_abbrev_equality("NE Foobar Crescent", "Northeast Foobar Cr")
    check_abbrev_equality("бул. Космонавтов", "бульвар Космонавтов")
    check_abbrev_equality("Hauptstr.", "Hauptstraße")
    check_abbrev_equality("Hauptstrasse", "Hauptstr.")
    check_abbrev_equality("Hubertus-Platz", "Hubertus-Pl.")
    check_abbrev_equality("Herreng.", "Herrengasse")
    check_abbrev_equality("Musterwg.", "Musterweg")
  end

  private
  # utility func to make output from failed tests more useful
  def check_abbrev_equality(a, b)
    assert_equal(true, Abbrev.equal_expansions(a, b), "Expecting #{a.inspect} to equal #{b.inspect} under abbreviation/expansion, but it doesn't.")
  end
end


if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

