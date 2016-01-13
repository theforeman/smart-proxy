require 'test_helper'

class RingBufferTest < Test::Unit::TestCase
  SIZE = 3

  def setup
    @buffer = Proxy::LogBuffer::RingBuffer.new(SIZE)
  end

  def test_should_be_empty
    assert_equal false, @buffer.full?
    @buffer.iterate_ascending { |x| fail }
    @buffer.iterate_descending { |x| fail }
  end

  def test_should_store_one_value
    @buffer.push(:a)
    assert_equal 1, @buffer.count
  end

  def test_should_contain_one_value
    @buffer.push(:a)
    @buffer.iterate_ascending { |x| assert_equal :a, x }
  end

  def test_should_store_size
    1.step(SIZE) { |i| @buffer.push(i) }
    assert_equal [1, 2, 3], @buffer.to_a
  end

  def test_copy_should_store_values
    @buffer.push(:a)
    @buffer.push(:b)
    new_buffer = @buffer.copy(SIZE)
    assert_equal [:a, :b], new_buffer.to_a
  end

  def test_full_buffer
    1.step(SIZE) { |i| @buffer.push(i) }
    assert @buffer.full?
  end

  def test_should_store_size_plus_one
    1.step(SIZE + 1) { |i| @buffer.push(i) }
    assert_equal [2, 3, 4], @buffer.to_a
  end

  def test_clear
    1.step(SIZE) { |i| @buffer.push(i) }
    @buffer.clear
    assert_equal [], @buffer.to_a
  end
end
