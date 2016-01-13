require 'test_helper'

class DecoratorTest < Test::Unit::TestCase
  SIZE = 10
  SIZE_TAIL = 5

  DEBUG = ::Logger::Severity::DEBUG
  INFO = ::Logger::Severity::INFO
  ERR = ::Logger::Severity::ERROR

  def setup
    @buffer = Proxy::LogBuffer::Buffer.new(SIZE, SIZE_TAIL, ERR)
    @logger = ::Logger.new("/dev/null")
    @logger.level = INFO
    @decorator = ::Proxy::LogBuffer::Decorator.new(@logger, @buffer)
  end

  def test_should_not_ignore_infos
    1.step(5) { |i| @decorator.info(i) }
    assert_equal [1, 2, 3, 4, 5], @buffer.to_a.collect(&:message)
  end

  def test_should_ignore_debugs
    1.step(5) { |i| @decorator.debug(i) }
    assert_equal [], @buffer.to_a.collect(&:message)
  end

  def test_should_not_ignore_debugs
    @logger.level = DEBUG
    1.step(5) { |i| @decorator.debug(i) }
    assert_equal [1, 2, 3, 4, 5], @buffer.to_a.collect(&:message)
  end
end
