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
  def test_abbrev_english
    check_abbrev_equality("Foobar Rd", "Foobar Road")
    check_abbrev_equality("Foobar Road", "Foobar Rd")
    check_abbrev_equality("E Foobar Wy", "East Foobar Way")
    check_abbrev_equality("NE Foobar Crescent", "North East Foobar Cr.")
    check_abbrev_equality("N.E. Foobar Crescent", "North East Foobar Cr")
    check_abbrev_equality("NE Foobar Crescent", "Northeast Foobar Cr")
    check_abbrev_equality("North & Western", "North and Western")

    check_abbrev_inequality("North & Western", "North and East")
  end

  def test_abbrev_russian
    check_abbrev_equality("бул. Космонавтов", "бульвар Космонавтов")
    check_abbrev_equality("пр-кт. Надеяться", "проспект Надеяться")

    check_abbrev_inequality("ул. Космонавтов", "бульвар Космонавтов")
  end

  def test_abbrev_german_normal
    check_abbrev_equality("Joh.-Seb.-Bach-Straße", "Johann-Sebastian-Bach-str.")
    check_abbrev_equality("Bettina-v-Arnim-Straße","Bettina-von-Arnim-Straße")
    check_abbrev_equality("Universität Münster","Uni Münster")
    check_abbrev_equality("Kindergarten Jahnstraße","KiGa Jahnstraße")
    check_abbrev_equality("Kl. Moor","Kleines Moor")
    check_abbrev_equality("Realschule Stralsund","RS Stralsund")
    check_abbrev_equality("Bgm. Willhelm str.", "Bürgermeister Willhelm straße")
    check_abbrev_equality("Hubertus-Platz", "Hubertus-Pl.")
    check_abbrev_equality("Fachhochschule Bremen","FH Bremen")
    check_abbrev_equality("An der Bahn","A. d. Bahn")
    check_abbrev_equality("Groß Ippener","Gr. Ippener")
    check_abbrev_equality("Klein Ippener","Kl Ippener")

    check_abbrev_inequality("Klein Ippener","Gr. Ippener")
  end

  def test_abbrev_german_abbrev_word_end
    check_abbrev_equality("Streitwagenwg","Streitwagenweg")
    check_abbrev_equality("Musterwg.", "Musterweg")
    check_abbrev_equality("Herreng.", "Herrengasse")
    check_abbrev_equality("Hauptstrasse", "Hauptstr.")
    check_abbrev_equality("Hauptstr.", "Hauptstraße")

    # check_abbrev_equality("Hauptstrasse", "Hauptstraße") # Are they should be equal?
  end

  def test_abbrev_german_diff_wordcounts
    check_abbrev_equality("Nürnbergerstraße","Nürnberger Str.")
  end

  private
  # utility func to make output from failed tests more useful
  def check_abbrev_equality(a, b)
    assert_equal(true, Abbrev.equal_expansions(a, b), "Expecting #{a.inspect} to equal #{b.inspect} under abbreviation/expansion, but it doesn't.")
  end

  def check_abbrev_inequality(a, b)
    assert_equal(false, Abbrev.equal_expansions(a, b), "Expecting #{a.inspect} to differ from #{b.inspect} under abbreviation/expansion, but it doesn't.")
  end
end


if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

