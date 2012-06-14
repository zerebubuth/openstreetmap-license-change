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
    "NE Foobar Crescent" => "North East Foobar Cr",
    "N.E. Foobar Crescent" => "North East Foobar Cr",
    "NE Foobar Street" => "Northeast Foobar St",
    "Foo & Bar" => "Foo and Bar",
    "Foo&Bar" => "Foo and Bar",
    "North & Western" => "North and Western",
    "Doublespace  St" => "Doublespace street",
    "New NW Route" => "New North West Route",
    "The old road " => "The old road",
    "Foo cres." => "Foo cr",
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
    "Hansel & Gretzel" => "Hansel und Gretzel",
    "Streitwagenwg" => "Streitwagenweg",
    "Musterwg." => "Musterweg",
    "Herreng." => "Herrengasse",
    "Hauptstrasse" => "Hauptstr.",
    "Hauptstr." => "Hauptstraße",
    "Nürnbergerstraße" => "Nürnberger Str.",
    #"Hauptstrasse" => "Hauptstraße", We handle this in tags.rb
  }
  
  INQUAL_STRINGS = {
    # English
    "& & A & B &&" => "A & B",
    "Foo & Bar" => "Foo Bar",
    "Westminster st" => "Westminster abby",
    "Camp east York" => "Cape York",
    "Doctor Feelgood" => "Drive Feelgood",
    "North & Western" => "North and East",
    # Russian
    "ул. Космонавтов" => "бульвар Космонавтов",
    # German
    "Klein Ippener" => "Gr. Ippener",
    "Westminster st" => "Westminster abby",
    "Camp east York" => "Cape York",
    "Doctor Feelgood" => "Drive Feelgood",
    "der foo" => "den foo",
  }

  EQUAL_STRINGS.each do |k, v|
    define_method("test_abbrev_#{k}") {
      check_abbrev_equality("#{k}", "#{v}")
      check_abbrev_equality("#{v}", "#{k}")
    }
  end
  
  INQUAL_STRINGS.each do |k, v|
    define_method("test_abbrev_#{k}") {
      check_abbrev_inquality("#{k}", "#{v}")
      check_abbrev_inquality("#{v}", "#{k}")
    }
  end

  private
  # utility func to make output from failed tests more useful
  def check_abbrev_equality(a, b)
    assert_equal(true, abbrev_equals(a, b), "Expecting #{a.inspect} to equal #{b.inspect} under abbreviation/expansion, but it doesn't.")
  end

  def check_abbrev_inquality(a, b)
    assert_equal(false, abbrev_equals(a, b), "Expecting #{a.inspect} to NOT equal #{b.inspect} under abbreviation/expansion, but it does.")
  end
  
  def abbrev_equals(a, b)
    #return Abbrev.equal_expansions(a, b)
    
    out = `./abbreviations.py "#{a}" "#{b}"`

    r = $?.exitstatus
    if r == 0 then
      return true
    elsif r == 2 then
      return false
    else
      raise "Error in 'abbreviations.py':\n #{out}"
    end
  end
end


if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

