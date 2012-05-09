require './diff'
require 'minitest/unit'

class TestDiff < MiniTest::Unit::TestCase
  def test_diff
    1000.times do
      a = 10.times.map { rand(5) }
      b = messup(a)
      
      d = Diff::diff(a, b)

      c = Diff::apply(d, a)
      
      assert_equal(c, b, "With a=#{a.inspect} and b=#{b.inspect}.")
    end
  end

  def test_compose_insert_insert
    check_compose([1,2,  3,  4,5],
                  [1,2,  3,6,4,5],
                  [1,2,7,3,6,4,5])

    check_compose([1,2,3,  4,  5],
                  [1,2,3,6,4,  5],
                  [1,2,3,6,4,7,5])

    check_compose([1,2,3,    4,5],
                  [1,2,3,6,  4,5],
                  [1,2,3,6,7,4,5])

    check_compose([1,2,3,    4,5],
                  [1,2,3,  6,4,5],
                  [1,2,3,7,6,4,5])
  end

  def test_compose_insert_delete
    check_compose([1,2,3,  4,5],
                  [1,2,3,6,4,5],
                  [1,  3,6,4,5])

    check_compose([1,2,  3,4,5],
                  [1,2,6,3,4,5],
                  [1,2,6,3,  5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,6,4,5],
                  [1,2,  6,4,5])

    check_compose([1,2,  3,4,5],
                  [1,2,6,3,4,5],
                  [1,2,6,  4,5])
  end

  def test_compose_insert_alter
    check_compose([1,2,3,  4,5],
                  [1,2,3,6,4,5],
                  [1,7,3,6,4,5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,6,4,5],
                  [1,2,3,6,4,7])

    check_compose([1,2,3,  4,5],
                  [1,2,3,6,4,5],
                  [1,2,7,6,4,5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,6,4,5],
                  [1,2,3,6,7,5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,6,4,5],
                  [1,2,3,7,4,5])
  end

  def test_compose_delete_insert
    check_compose([1,2,3,  4,5],
                  [1,  3,  4,5],
                  [1,  3,6,4,5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,  4  ],
                  [1,2,3,6,4  ])

    check_compose([1,2,3,  4,5],
                  [1,2,    4,5],
                  [1,2,  6,4,5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,    5],
                  [1,2,3,6,  5])
  end

  def test_compose_delete_delete
    check_compose([1,2,7,3,6,4,5],
                  [1,2,7,3,  4,5],
                  [1,2,  3,  4,5])

    check_compose([1,2,7,3,6,4,5],
                  [1,2,  3,6,4,5],
                  [1,2,  3,  4,5])

    check_compose([1,2,3,4,5],
                  [1,2,  4,5],
                  [1,    4,5])

    check_compose([1,2,3,4,5],
                  [1,2,  4,5],
                  [1,2,    5])
  end

  def test_compose_delete_alter
    check_compose([1,2,3,6,4,5],
                  [1,2,3,  4,5],
                  [1,7,3,  4,5])

    check_compose([1,2,3,6,4,5],
                  [1,2,3,  4,5],
                  [1,2,7,  4,5])

    check_compose([1,2,3,6,4,5],
                  [1,2,3,  4,5],
                  [1,2,3,  7,5])

    check_compose([1,2,3,6,4,5],
                  [1,2,3,  4,5],
                  [1,2,3,  4,7])
  end

  def test_compose_alter_insert
    check_compose([1,2,3,  4,5],
                  [1,7,3,  4,5],
                  [1,7,3,6,4,5])

    check_compose([1,2,3,  4,5],
                  [1,2,7,  4,5],
                  [1,2,7,6,4,5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,  7,5],
                  [1,2,3,6,7,5])

    check_compose([1,2,3,  4,5],
                  [1,2,3,  4,7],
                  [1,2,3,6,4,7])
  end

  def test_compose_alter_delete
    check_compose([1,2,3,4,5],
                  [1,2,3,7,5],
                  [1,2,3,  5])

    check_compose([1,2,3,6,4,5],
                  [1,7,3,6,4,5],
                  [1,7,3,  4,5])

    check_compose([1,2,3,6,4,5],
                  [1,2,7,6,4,5],
                  [1,2,7,  4,5])

    check_compose([1,2,3,6,4,5],
                  [1,2,3,6,7,5],
                  [1,2,3,  7,5])

    check_compose([1,2,3,6,4,5],
                  [1,2,3,6,4,7],
                  [1,2,3,  4,7])
  end

  def test_compose_alter_alter
    check_compose([1,2,3,4,5],
                  [1,7,3,4,5],
                  [1,7,3,6,5])

    check_compose([1,2,3,4,5],
                  [1,2,7,4,5],
                  [1,2,7,6,5])

    check_compose([1,2,3,4,5],
                  [1,2,3,4,7],
                  [1,2,3,6,7])

    check_compose([1,2,3,4,5],
                  [1,2,3,4,7],
                  [1,2,6,4,7])

    check_compose([1,2,3,4,5],
                  [1,2,7,4,5],
                  [1,2,6,4,5])
  end

  def test_compose_1
    a = [3, 4, 2, 0, 2      ]
    b = [   4, 2,    2, 2, 1]
    c = [   4, 2,          0]

    check_compose(a, b, c)
  end

  def test_compose_2
    a = [3,          2, 4,       1, 4, 1, 4, 2,    3,    3   ]
    b = [   2,    2, 4, 0, 1,                2, 0, 3, 4, 3   ]
    c = [   2, 0, 2,       1, 3,             2, 0, 3, 4, 4, 4]

    d_ab = Diff::diff(a, b)
    assert_equal([Diff::Delete.new(0,3), Diff::Insert.new(1,2), Diff::Insert.new(3,0), 
                  Diff::Delete.new(5,4), Diff::Delete.new(5,1), Diff::Delete.new(5,4), 
                  Diff::Insert.new(6,0), Diff::Insert.new(8,4)],
                 d_ab)
    
    d_bc = Diff::diff(b, c)
    assert_equal([Diff::Insert.new(1,0), Diff::Delete.new(3,4), Diff::Delete.new(3,0),
                  Diff::Insert.new(4,3), Diff::Alter.new(9,3,4), Diff::Insert.new(10,4)],
                 d_bc)

    check_compose(a, b, c)
  end

  def test_compose
    1000.times do
      a = 10.times.map { rand(5) }
      b = messup(a)
      c = messup(b)

      begin
        check_compose(a, b, c)
      rescue
        flunk("With a=#{a}, b=#{b}, c=#{c}: #{$!}")
      end
    end
  end

  private
  
  def messup(a)
    a.collect_concat do |ax| 
      case rand(3)
      when 0
        [ax]
      when 1
        [ax, rand(5)]
      when 2
        []
      end
    end
  end

  def check_compose(a, b, c)
    d_ab = Diff::diff(a, b)
    d_bc = Diff::diff(b, c)

    assert_equal(c, Diff::apply(d_bc, Diff::apply(d_ab, a)))

    d_xc, d_ax = Diff::compose(d_ab, d_bc)
    x = Diff::apply(d_ax, a)

    assert_equal(c, Diff::apply(d_xc, x), "With a=#{a}, b=#{b}, c=#{c}")
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end
