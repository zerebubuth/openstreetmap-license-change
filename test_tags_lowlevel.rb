require './tags'
require 'minitest/unit'

class TestTagsLowlevel < Minitest::Test

  #------------------------------------------------------------
  # some low-level tags checks.
  #------------------------------------------------------------

  def test_create_detection
    diff = Tags::Diff.create({}, {'foo' => 'bar'})
    assert_equal({}, diff.unchanged)
    assert_equal({'foo' => 'bar'}, diff.created)
    assert_equal({}, diff.deleted)
    assert_equal({}, diff.edited)
    assert_equal({}, diff.moved)    
  end

  def test_create_detection_with_existing
    diff = Tags::Diff.create({'foo' => 'bar'}, {'foo' => 'bar', 'bar' => 'bat'})
    assert_equal({'foo' => 'bar'}, diff.unchanged)
    assert_equal({'bar' => 'bat'}, diff.created)
    assert_equal({}, diff.deleted)
    assert_equal({}, diff.edited)
    assert_equal({}, diff.moved)    
  end

  def test_deletion
    diff = Tags::Diff.create({'foo' => 'bar'}, {})
    assert_equal({}, diff.unchanged)
    assert_equal({}, diff.created)
    assert_equal({'foo' => 'bar'}, diff.deleted)
    assert_equal({}, diff.edited)
    assert_equal({}, diff.moved)    
  end

  def test_deletion_with_existing
    diff = Tags::Diff.create({'foo' => 'bar', 'bar' => 'bat'}, {'foo' => 'bar'})
    assert_equal({'foo' => 'bar'}, diff.unchanged)
    assert_equal({}, diff.created)
    assert_equal({'bar' => 'bat'}, diff.deleted)
    assert_equal({}, diff.edited)
    assert_equal({}, diff.moved)    
  end

  def test_edited
    diff = Tags::Diff.create({'foo' => 'bar'}, {'foo' => 'baz'})
    assert_equal({}, diff.unchanged)
    assert_equal({}, diff.created)
    assert_equal({}, diff.deleted)
    assert_equal({'foo' => ['bar', 'baz']}, diff.edited)
    assert_equal({}, diff.moved)    
  end

  def test_edited_with_existing
    diff = Tags::Diff.create({'foo' => 'bar', 'bar' => 'bat'}, {'foo' => 'baz', 'bar' => 'bat'})
    assert_equal({'bar' => 'bat'}, diff.unchanged)
    assert_equal({}, diff.created)
    assert_equal({}, diff.deleted)
    assert_equal({'foo' => ['bar', 'baz']}, diff.edited)
    assert_equal({}, diff.moved)    
  end

  def test_moved
    diff = Tags::Diff.create({'foo' => 'bar'}, {'foop' => 'bar'})
    assert_equal({}, diff.unchanged)
    assert_equal({}, diff.created)
    assert_equal({}, diff.deleted)
    assert_equal({}, diff.edited)
    assert_equal({['foo', 'foop'] => 'bar'}, diff.moved)
  end

  def test_moved_with_existing
    diff = Tags::Diff.create({'foo' => 'bar', 'bar' => 'bat'}, {'foop' => 'bar', 'bar' => 'bat'})
    assert_equal({'bar' => 'bat'}, diff.unchanged)
    assert_equal({}, diff.created)
    assert_equal({}, diff.deleted)
    assert_equal({}, diff.edited)
    assert_equal({['foo', 'foop'] => 'bar'}, diff.moved)
  end

  def test_apply
    old = {
      'foo' => 'bar!',
      'foop' => 'bar_asdfgh',
      'bar' => 'baz',
      'baz' => 'bat'
    }
    new = {
      'foop' => 'bar_qwerty',
      'bark' => 'baz',
      'baz' => 'bat',
      'new' => 'shoes'
    }
    diff = Tags::Diff.create(old, new)
    assert_equal({'baz' => 'bat'}, diff.unchanged)
    assert_equal({'new' => 'shoes'}, diff.created)
    assert_equal({'foo' => 'bar!'}, diff.deleted)
    assert_equal({'foop' => ['bar_asdfgh','bar_qwerty']}, diff.edited)
    assert_equal({['bar', 'bark'] => 'baz'}, diff.moved)
    assert_equal(new, diff.apply(old))
  end    

  def test_apply_reverse
    old = {
      'foo' => 'bar!',
      'foop' => 'bar_asdfgh',
      'bar' => 'baz',
      'baz' => 'bat'
    }
    new = {
      'foop' => 'bar_qwerty',
      'bark' => 'baz',
      'baz' => 'bat',
      'new' => 'shoes'
    }
    diff = Tags::Diff.create(old, new)
    assert_equal({'baz' => 'bat'}, diff.unchanged)
    assert_equal({'new' => 'shoes'}, diff.created)
    assert_equal({'foo' => 'bar!'}, diff.deleted)
    assert_equal({'foop' => ['bar_asdfgh','bar_qwerty']}, diff.edited)
    assert_equal({['bar', 'bark'] => 'baz'}, diff.moved)
    assert_equal(old, diff.reverse.apply(new))
  end    
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end

