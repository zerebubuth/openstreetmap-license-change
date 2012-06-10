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

  EQUAL_STRINGS = {
    # English
    "Foobar Rd" => "Foobar Road",
    "Foobar Road" => "Foobar Rd",
    "E Foobar Wy" => "East Foobar Way",
    "NE Foobar Crescent" => "North East Foobar Cr.",
    "N.E. Foobar Crescent" => "North East Foobar Cr",
    "NE Foobar Street" => "Northeast Foobar St",
    "Foo & Bar" => "Foo and Bar",
    "Foo&Bar" => "Foo and Bar",
    "North & Western" => "North and Western",
    # Russian
    "бул. Космонавтов" => "бульвар Космонавтов",
    "пр-кт. Надеяться" => "проспект Надеяться",
    # German
    "Joh.-Seb.-Bach-Straße" => "Johann-Sebastian-Bach-str.",
    "Bettina-v-Arnim-Straße" => "Bettina-von-Arnim-Straße",
    "Universität Münster" => "Uni Münster",
    "Kindergarten Jahnstraße" => "KiGa Jahnstraße",
    "Kl. Moor" => "Kleines Moor",
    "Realschule Stralsund" => "RS Stralsund",
    "Bgm. Willhelm str." => "Bürgermeister Willhelm straße",
    "Hubertus-Platz" => "Hubertus-Pl.",
    "Fachhochschule Bremen" => "FH Bremen",
    "An der Bahn" => "A. d. Bahn",
    "Groß Ippener" => "Gr. Ippener",
    "Klein Ippener" => "Kl Ippener",
    
    "Streitwagenwg" => "Streitwagenweg",
    "Musterwg." => "Musterweg",
    "Herreng." => "Herrengasse",
    "Hauptstrasse" => "Hauptstr.",
    "Hauptstr." => "Hauptstraße",
    "Nürnbergerstraße" => "Nürnberger Str.",
    "Hauptstrasse" => "Hauptstraße",
  }
  
  INQUAL_STRINGS = {
    # English
    "& & A & B &&" => "A & B",
    "Foo & Bar" => "Foo Bar",
    "North & Western" => "North and East",
    # Russian
    "ул. Космонавтов" => "бульвар Космонавтов",
    # German
    "Klein Ippener" => "Gr. Ippener",
  }

  EQUAL_STRINGS.each do |k, v|
    define_method("test_abbrev_#{k}") {
      check_abbrev_equality("#{k}", "#{v}")
    }
  end
  
  INQUAL_STRINGS.each do |k, v|
    define_method("test_abbrev_#{k}") {
      check_abbrev_inquality("#{k}", "#{v}")
    }
  end

  private
  # utility func to make output from failed tests more useful
  def check_abbrev_equality(a, b)
    assert_equal(true, Abbrev.equal_expansions(a, b), "Expecting #{a.inspect} to equal #{b.inspect} under abbreviation/expansion, but it doesn't.")
  end

  def check_abbrev_inquality(a, b)
    assert_equal(false, Abbrev.equal_expansions(a, b), "Expecting #{a.inspect} to NOT equal #{b.inspect} under abbreviation/expansion, but it does.")
  end
end


if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

