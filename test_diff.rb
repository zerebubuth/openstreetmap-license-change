require './diff'
require 'minitest/unit'

class TestDiff < Minitest::Test
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

    d_ab = Diff::diff(a, b, :detect_alter => (Proc.new {|a,b| true}))
    assert_equal([Diff::Delete.new(0,3), Diff::Insert.new(1,2), Diff::Insert.new(3,0), 
                  Diff::Delete.new(5,4), Diff::Delete.new(5,1), Diff::Delete.new(5,4), 
                  Diff::Insert.new(6,0), Diff::Insert.new(8,4)],
                 d_ab)
    
    d_bc = Diff::diff(b, c, :detect_alter => (Proc.new {|a,b| true}))
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

  def test_move_detect
    a = [1, 2, 3,    4, 5, 6, 7, 8, 9]
    b = [1, 2, 3, 7, 4, 5, 6,    8, 9]
    d = Diff::diff(a, b, :detect_move => true)
    assert_equal([Diff::Move.new(6, 3, 7)], d)
    x = Diff::apply(d, a)
    assert_equal(b, x)
  end

  def test_move_with_other_changes
    a = [   1, 2, 3,    4, 5, 6, 7, 8, 9    ]
    b = [0, 1,    3, 7, 4, 5, 6,    8, 9, 10]
    d = Diff::diff(a, b, :detect_move => true)
    assert_equal([Diff::Insert.new(0, 0), 
                  Diff::Delete.new(2, 2), 
                  Diff::Move.new(6, 3, 7), 
                  Diff::Insert.new(9, 10)
                 ], d)
    x = Diff::apply(d, a)
    assert_equal(b, x)
  end

  def test_move_back_null
    a = [1,    2, 3, 4, 5, 6]
    b = [1, 5, 2, 3, 4,    6]

    check_diff_move(a, b)
  end

  def test_move_back_del
    a = [1,    2, 3, 4, 5, 6]
    b = [1, 5, 2,    4,    6]

    check_diff_move(a, b)
  end

  def test_move_back_ins
    a = [1,    2, 3,    4, 5, 6]
    b = [1, 5, 2, 3, 9, 4,    6]

    check_diff_move(a, b)
  end

  def test_move_fwd_null
    a = [1, 5, 2, 3, 4,    6]
    b = [1,    2, 3, 4, 5, 6]

    check_diff_move(a, b)
  end

  def test_move_fwd_ins
    a = [1, 5, 2,    4,    6]
    b = [1,    2, 3, 4, 5, 6]

    check_diff_move(a, b)
  end

  def test_move_fwd_del
    a = [1, 5, 2, 3, 9, 4,    6]
    b = [1,    2, 3,    4, 5, 6]

    check_diff_move(a, b)
  end

  def test_compose_insert_move
    # with move going backwards
    check_compose_move([1,    2, 3, 4, 5   ],
                       [1,    2, 3, 4, 5, 9],
                       [1, 4, 2, 3,    5, 9])

    check_compose_move([1,    2, 3, 4,    5],
                       [1,    2, 3, 4, 9, 5],
                       [1, 4, 2, 3,    9, 5])

    check_compose_move([1,    2, 3,    4, 5],
                       [1,    2, 3, 9, 4, 5],
                       [1, 4, 2, 3, 9,    5])

    check_compose_move([1,    2,    3, 4, 5],
                       [1,    2, 9, 3, 4, 5],
                       [1, 4, 2, 9, 3,    5])

    check_compose_move([1,       2, 3, 4, 5],
                       [1,    9, 2, 3, 4, 5],
                       [1, 4, 9, 2, 3,    5])

    check_compose_move([1,       2, 3, 4, 5],
                       [1, 9,    2, 3, 4, 5],
                       [1, 9, 4, 2, 3,    5])

    check_compose_move([   1,    2, 3, 4, 5],
                       [9, 1,    2, 3, 4, 5],
                       [9, 1, 4, 2, 3,    5])

    # with move going forwards
    check_compose_move([1, 4, 2, 3,    5   ],
                       [1, 4, 2, 3,    5, 9],
                       [1,    2, 3, 4, 5, 9])

    check_compose_move([1, 4, 2, 3,       5],
                       [1, 4, 2, 3,    9, 5],
                       [1,    2, 3, 4, 9, 5])

    check_compose_move([1, 4, 2, 3,       5],
                       [1, 4, 2, 3, 9,    5],
                       [1,    2, 3, 9, 4, 5])

    check_compose_move([1, 4, 2,    3,    5],
                       [1, 4, 2, 9, 3,    5],
                       [1,    2, 9, 3, 4, 5])

    check_compose_move([1, 4,    2, 3,    5],
                       [1, 4, 9, 2, 3,    5],
                       [1,    9, 2, 3, 4, 5])

    check_compose_move([1,    4, 2, 3,    5],
                       [1, 9, 4, 2, 3,    5],
                       [1, 9,    2, 3, 4, 5])

    check_compose_move([   1, 4, 2, 3,    5],
                       [9, 1, 4, 2, 3,    5],
                       [9, 1,    2, 3, 4, 5])
  end

  def test_compose_move_insert
    # going backwards...
    check_compose_move([1,    2, 3, 4, 5   ],
                       [1, 4, 2, 3,    5   ],
                       [1, 4, 2, 3,    5, 9])

    check_compose_move([1,    2, 3,    4, 5],
                       [1, 4, 2, 3,       5],
                       [1, 4, 2, 3, 9,    5])

    check_compose_move([1,    2,    3, 4, 5],
                       [1, 4, 2,    3,    5],
                       [1, 4, 2, 9, 3,    5])

    check_compose_move([1,       2, 3, 4, 5],
                       [1, 4,    2, 3,    5],
                       [1, 4, 9, 2, 3,    5])

    check_compose_move([1,       2, 3, 4, 5],
                       [1,    4, 2, 3,    5],
                       [1, 9, 4, 2, 3,    5])

    check_compose_move([   1,    2, 3, 4, 5],
                       [   1, 4, 2, 3,    5],
                       [9, 1, 4, 2, 3,    5])

    # going forwards...
    check_compose_move([   1, 4, 2, 3,    5],
                       [   1,    2, 3, 4, 5],
                       [9, 1,    2, 3, 4, 5])

    check_compose_move([1, 4, 2, 3,    5],
                       [1,    2, 3, 4, 5],
                       [1, 9, 2, 3, 4, 5])

    check_compose_move([1, 4, 2,    3,    5],
                       [1,    2,    3, 4, 5],
                       [1,    2, 9, 3, 4, 5])

    check_compose_move([1, 4, 2, 3,       5],
                       [1,    2, 3,    4, 5],
                       [1,    2, 3, 9, 4, 5])

    check_compose_move([1, 4, 2, 3,       5],
                       [1,    2, 3, 4,    5],
                       [1,    2, 3, 4, 9, 5])

    check_compose_move([1, 4, 2, 3,    5   ],
                       [1,    2, 3, 4, 5   ],
                       [1,    2, 3, 4, 5, 9])
  end

  def test_compose_delete_move
    # going backwards...
    check_compose_move([9, 1,    2, 3, 4, 5],
                       [   1,    2, 3, 4, 5],
                       [   1, 4, 2, 3,    5])

    check_compose_move([1, 9, 2, 3, 4, 5],
                       [1,    2, 3, 4, 5],
                       [1, 4, 2, 3,    5])

    check_compose_move([1,    2, 9, 3, 4, 5],
                       [1,    2,    3, 4, 5],
                       [1, 4, 2,    3,    5])

    check_compose_move([1,    2, 3, 9, 4, 5],
                       [1,    2, 3,    4, 5],
                       [1, 4, 2, 3,       5])

    check_compose_move([1,    2, 3, 4, 9, 5],
                       [1,    2, 3, 4,    5],
                       [1, 4, 2, 3,       5])

    check_compose_move([1,    2, 3, 4, 5, 9],
                       [1,    2, 3, 4, 5   ],
                       [1, 4, 2, 3,    5   ])

    # going forwards...
    check_compose_move([9, 1, 4, 2, 3,    5],
                       [   1, 4, 2, 3,    5],
                       [   1,    2, 3, 4, 5])

    check_compose_move([1, 9, 4, 2, 3,    5],
                       [1,    4, 2, 3,    5],
                       [1,       2, 3, 4, 5])

    check_compose_move([1, 4, 9, 2, 3,    5],
                       [1, 4,    2, 3,    5],
                       [1,       2, 3, 4, 5])

    check_compose_move([1, 4, 2, 9, 3,    5],
                       [1, 4, 2,    3,    5],
                       [1,    2,    3, 4, 5])

    check_compose_move([1, 4, 2, 3, 9, 5],
                       [1, 4, 2, 3,    5],
                       [1,    2, 3, 4, 5])

    check_compose_move([1, 4, 2, 3,    5, 9],
                       [1, 4, 2, 3,    5   ],
                       [1,    2, 3, 4, 5   ])
  end

  def test_compose_move_delete
    # going backwards...
    check_compose_move([9, 1,    2, 3, 4, 5],
                       [9, 1, 4, 2, 3,    5],
                       [   1, 4, 2, 3,    5])

    check_compose_move([1, 9,    2, 3, 4, 5],
                       [1, 9, 4, 2, 3,    5],
                       [1,    4, 2, 3,    5])

    check_compose_move([1,    9, 2, 3, 4, 5],
                       [1, 4, 9, 2, 3,    5],
                       [1, 4,    2, 3,    5])

    check_compose_move([1,    2, 9, 3, 4, 5],
                       [1, 4, 2, 9, 3,    5],
                       [1, 4, 2,    3,    5])

    check_compose_move([1,    2, 3, 9, 4, 5],
                       [1, 4, 2, 3, 9,    5],
                       [1, 4, 2, 3,       5])

    check_compose_move([1,    2, 3, 4, 9, 5],
                       [1, 4, 2, 3,    9, 5],
                       [1, 4, 2, 3,       5])

    check_compose_move([1,    2, 3, 4, 5, 9],
                       [1, 4, 2, 3,    5, 9],
                       [1, 4, 2, 3,    5   ])

    # going forwards...
    check_compose_move([9, 1, 4, 2, 3,    5],
                       [9, 1,    2, 3, 4, 5],
                       [   1,    2, 3, 4, 5])

    check_compose_move([1, 9, 4, 2, 3,    5],
                       [1, 9,    2, 3, 4, 5],
                       [1,       2, 3, 4, 5])

    check_compose_move([1, 4, 9, 2, 3,    5],
                       [1,    9, 2, 3, 4, 5],
                       [1,       2, 3, 4, 5])

    check_compose_move([1, 4, 2, 9, 3,    5],
                       [1,    2, 9, 3, 4, 5],
                       [1,    2,    3, 4, 5])

    check_compose_move([1, 4, 2, 3, 9,    5],
                       [1,    2, 3, 9, 4, 5],
                       [1,    2, 3,    4, 5])

    check_compose_move([1, 4, 2, 3,    9, 5],
                       [1,    2, 3, 4, 9, 5],
                       [1,    2, 3, 4,    5])

    check_compose_move([1, 4, 2, 3,    5, 9],
                       [1,    2, 3, 4, 5, 9],
                       [1,    2, 3, 4, 5   ])
  end

  def test_compose_move_alter
    n = 5
    a = (1..n).to_a
    n.times do |i|
      (n-1).times do |j|
        b = a.clone
        bx = b.delete_at(i)
        b.insert(j, bx)

        n.times do |k|
          c = b.clone
          c[k] = 9

          check_compose_move(a, b, c)
        end
      end
    end
  end

  def test_compose_alter_move
    n = 5
    a = (1..n).to_a
    n.times do |i|
      b = a.clone
      b[i] = 9
      n.times do |j|
        (n-1).times do |k|
          c = b.clone
          cx = c.delete_at(j)
          c.insert(k, cx)

          check_compose_move(a, b, c)
        end
      end
    end
  end

  def test_compose_move_move
    n = 5
    a = (1..n).to_a
    n.times do |bi|
      (n-1).times do |bj|
        b = a.clone
        bx = b.delete_at(bi)
        b.insert(bj, bx)
        
        n.times do |ci|
          (n-1).times do |cj|
            c = b.clone
            cx = c.delete_at(ci)
            c.insert(cj, cx)

            check_compose_move(a, b, c)
          end
        end
      end
    end
  end

  def test_compose_move
    1000.times do
      a = 10.times.map { rand(5) }
      b = messup(a)
      c = messup(b)

      begin
        d_ab = Diff::diff(a, b, :detect_alter => Proc.new {true}, :detect_move => true)
        d_bc = Diff::diff(b, c, :detect_alter => Proc.new {true}, :detect_move => true)
        
        assert_equal(c, Diff::apply(d_bc, Diff::apply(d_ab, a)))
        
        d_xc, d_ax = Diff::compose(d_ab, d_bc)
        x = Diff::apply(d_ax, a)
        
        assert_equal(c, Diff::apply(d_xc, x), "With a=#{a}, b=#{b}, c=#{c}")
        
      rescue
        flunk("With a=#{a}, b=#{b}, c=#{c}: #{$!}")
      end
    end
  end

  def test_split_deletes
    1000.times do
      a = 10.times.map { rand(5) }
      b = messup(a)
      
      d = Diff::diff(a, b, :detect_alter => (Proc.new {|a,b| true}))

      delete, others = Diff::split_deletes(d)
      
      x = Diff::apply(others, Diff::apply(delete, a))

      assert_equal(x, b, "With a=#{a.inspect} and b=#{b.inspect}.")
    end
  end

  def test_example_way6510000
    history = [[53120720,53100737,53182378,59699628,53109829,53092498,53099797,53163625,59713406,53187519,53175980,53196350,59594033,59594034,59594035,59594036,59594031], 
               [53120720,53100737,53182378,59699628,53109829,53092498,53099797,53163625,59713406,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,53099797,53163625,59713406,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,59713406,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,59713406,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,59713406,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,59713406,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,340259221,59713406,340259222,340259223,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,340259221,59713406,340259222,340259223,53187519,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,340259221,59713406,340259222,340259223,53187519,340259263,340259264,53175980,53196350], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,340259221,59713406,340259222,340259223,53187519], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,340259221,59713406,340259322,340259323,340259295], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,340259221,59713406,340259322,340259323,340259295], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,206249655,53099797,53163625,340259221,59713406,340259322,340259323,340259295], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,53099797,53163625,340259221,59713406,340259322,340259323,340259295], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,53099797,53163625,340259221,59713406,340259322,340259323,340259295], 
               [53120720,53100737,53182378,59699628,53109829,206249014,53092498,53099797,53163625,340259221,59713406,340259322,340259323,340259295]]

    agreed = [true, true, true, true, false, false, false, false, false, false, false, false, true, true, true, false, true]

    # just checking...
    assert_equal agreed.length, history.length

    last = []
    state = []
    clean = []
    history.zip(agreed).each do |cur, agree|
      diff = Diff::diff(last, cur)
      state, xdiff = Diff::compose(state, diff)

      if agree
        clean = Diff::apply(xdiff, clean)

      else
        del, oth = Diff::split_deletes(xdiff)
        clean = Diff::apply(del, clean)
        state[0...0] = oth
      end

      last = cur
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
    d_ab = Diff::diff(a, b, :detect_alter => (Proc.new {|a,b| true}))
    d_bc = Diff::diff(b, c, :detect_alter => (Proc.new {|a,b| true}))

    assert_equal(c, Diff::apply(d_bc, Diff::apply(d_ab, a)))

    d_xc, d_ax = Diff::compose(d_ab, d_bc)
    x = Diff::apply(d_ax, a)

    assert_equal(c, Diff::apply(d_xc, x), "With a=#{a}, b=#{b}, c=#{c}")
  end

  def check_diff_move(a, b)
    d = Diff::diff(a, b, :detect_move => true)
    assert_equal(b, Diff::apply(d, a))
  end

  def check_compose_move(a, b, c)
    d_ab = Diff::diff(a, b, :detect_alter => (Proc.new {|a,b| true}), :detect_move => true)
    d_bc = Diff::diff(b, c, :detect_alter => (Proc.new {|a,b| true}), :detect_move => true)

    assert_equal(c, Diff::apply(d_bc, Diff::apply(d_ab, a)))

    #puts 
    #puts "A: #{a.inspect}"
    #puts "B: #{b.inspect}"
    #puts "C: #{c.inspect}"
    #puts "A->B: #{d_ab.inspect}"
    #puts "B->C: #{d_bc.inspect}"
    d_xc, d_ax = Diff::compose(d_ab, d_bc)
    #puts "A->X: #{d_ax.inspect}"
    #puts "X->C: #{d_xc.inspect}"
    x = Diff::apply(d_ax, a)
    #puts "X: #{x.inspect}"

    assert_equal(c, Diff::apply(d_xc, x), "With a=#{a}, b=#{b}, c=#{c}")

  rescue
    flunk("With a=#{a}, b=#{b}, c=#{c}: #{$!}")
  end
end

if __FILE__ == $0
    MiniTest::Unit.new.run(ARGV)
end
