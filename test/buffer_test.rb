require 'test_helper'

class RingBufferTest < Test::Unit::TestCase
  SIZE = 3

  def setup
    @buffer = Proxy::Events::RingBuffer.new(SIZE)
  end

  def test_should_be_empty
    assert_false @buffer.full?
    @buffer.iterate_ascending { |_| fail }
    @buffer.iterate_descending { |_| fail }
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

class BufferTest < Test::Unit::TestCase
  SIZE      = 3
  SIZE_TAIL = 2

  DEBUG = ::Logger::Severity::DEBUG
  INFO  = ::Logger::Severity::INFO
  ERR   = ::Logger::Severity::ERROR

  def setup
    @buffer = Proxy::Events::Buffer.new
    @buffer.setup_buffers(SIZE, SIZE_TAIL, INFO, ERR)
  end

  def log_event(*args)
    Proxy::Events::BacktraceLogEvent.new(*args)
  end

  def test_should_be_empty
    @buffer.iterate_ascending { |_| fail }
    @buffer.iterate_descending { |_| fail }
  end

  def test_should_contain_one_value
    @buffer.push(log_event(nil, Time.now.utc.to_i, ERR, 'msg'))
    @buffer.iterate_ascending { |x| assert_equal 'msg', x.message }
  end

  def test_should_store_size
    1.step(SIZE) { |i| @buffer.push(log_event(nil, Time.now.utc.to_i, ERR, i)) }
    assert_equal [1, 2, 3], @buffer.to_a.collect(&:message)
  end

  def test_should_store_full_size_errors
    1.step(SIZE + SIZE_TAIL) { |i| @buffer.push(log_event(nil, Time.now.utc.to_i, ERR, i)) }
    assert_equal [1, 2, 3, 4, 5], @buffer.to_a.collect(&:message)
  end

  def test_should_store_full_size_plus_one_errors
    1.step(SIZE + SIZE_TAIL + 1) { |i| @buffer.push(log_event(nil, Time.now.utc.to_i, ERR, i)) }
    assert_equal [2, 3, 4, 5, 6], @buffer.to_a.collect(&:message)
  end

  def test_should_store_full_size_plus_one_info
    1.step(SIZE + SIZE_TAIL + 1) { |i| @buffer.push(log_event(nil, Time.now.utc.to_i, INFO, i)) }
    assert_equal [4, 5, 6], @buffer.to_a.collect(&:message)
  end

  def test_should_ignore_debugs
    1.step(SIZE + SIZE_TAIL + 1) { |i| @buffer.push(log_event(nil, Time.now.utc.to_i, DEBUG, i)) }
    assert_equal [], @buffer.to_a.collect(&:message)
  end
end
