require 'test_helper'

class BufferTest < Test::Unit::TestCase
  SIZE = 3
  SIZE_TAIL = 2

  DEBUG = ::Logger::Severity::DEBUG
  INFO = ::Logger::Severity::INFO
  ERR = ::Logger::Severity::ERROR

  def setup
    @buffer = Proxy::LogBuffer::Buffer.new(SIZE, SIZE_TAIL, ERR)
  end

  def test_size
    assert_equal SIZE, @buffer.size
  end

  def test_size_tail
    assert_equal SIZE_TAIL, @buffer.size_tail
  end

  def log_event(*args)
    Proxy::LogBuffer::LogRecord.new(*args)
  end

  def test_should_be_empty
    @buffer.iterate_ascending { |x| fail }
    @buffer.iterate_descending { |x| fail }
  end

  def test_should_contain_one_value
    @buffer.push(log_event(Time.now.utc.to_f, ERR, "msg"))
    @buffer.iterate_ascending { |x| assert_equal "msg", x.message }
  end

  def test_should_store_size
    1.step(SIZE) { |i| @buffer.push(log_event(Time.now.utc.to_f, ERR, i)) }
    assert_equal [1, 2, 3], @buffer.to_a.collect(&:message)
  end

  def test_should_store_full_size_errors
    1.step(SIZE + SIZE_TAIL) { |i| @buffer.push(log_event(Time.now.utc.to_f, ERR, i)) }
    assert_equal [1, 2, 3, 4, 5], @buffer.to_a.collect(&:message)
  end

  def test_should_store_full_size_plus_one_errors
    1.step(SIZE + SIZE_TAIL + 1) { |i| @buffer.push(log_event(Time.now.utc.to_f, ERR, i)) }
    assert_equal [2, 3, 4, 5, 6], @buffer.to_a.collect(&:message)
  end

  def test_should_store_full_size_plus_one_info
    1.step(SIZE + SIZE_TAIL + 1) { |i| @buffer.push(log_event(Time.now.utc.to_f, INFO, i)) }
    assert_equal [4, 5, 6], @buffer.to_a.collect(&:message)
  end
end
