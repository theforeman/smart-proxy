require 'test_helper'

class DecoratorTest < Test::Unit::TestCase
  class DecoratorForTesting < ::Proxy::LogBuffer::Decorator
    attr_reader :logger
  end

  SIZE = 10
  SIZE_TAIL = 5

  DEBUG = ::Logger::Severity::DEBUG
  INFO = ::Logger::Severity::INFO
  WARNING = ::Logger::Severity::WARN
  ERR = ::Logger::Severity::ERROR
  FATAL = ::Logger::Severity::FATAL

  def setup
    @buffer = Proxy::LogBuffer::Buffer.new(SIZE, SIZE_TAIL, ERR)
    @logger = ::Logger.new("/dev/null")
    @logger.level = INFO
    @decorator = ::Proxy::LogBuffer::Decorator.new(@logger, "STDOUT", @buffer)
  end

  def test_add_no_message
    @logger.expects(:add).with(WARNING, nil)
    @buffer.expects(:push)
    @decorator.add(::Logger::Severity::WARN)
  end

  def test_add_text_message
    @logger.expects(:add).with(WARNING, "text")
    @buffer.expects(:push)
    @decorator.add(::Logger::Severity::WARN, "text")
  end

  def test_add_exception
    exception = Exception.new("ex")
    @logger.expects(:add).with(WARNING, "test")
    @buffer.expects(:push)
    @decorator.expects(:exception).with("Error details for test", exception)
    @decorator.add(::Logger::Severity::WARN, "test", nil, exception)
  end

  def test_add_backtrace_array_legacy
    exception = ['backtrace1', 'backtrace2']
    @logger.expects(:add).with(WARNING, "test")
    @buffer.expects(:push)
    @decorator.add(::Logger::Severity::WARN, "test", nil, exception)
  end

  def test_should_pass_logs
    @logger.expects(:add).with(DEBUG, "message")
    @decorator.debug("message")
  end

  def test_should_pass_logs_to_syslog
    # nothing is actually logged to SYSLOG during the test
    require 'syslog/logger'
    @logger = ::Syslog::Logger.new 'decorator-test'
    @decorator = ::Proxy::LogBuffer::Decorator.new(@logger, @buffer)
    @logger.expects(:add).with(FATAL, "message")
    @decorator.fatal("message")
  rescue LoadError
    # skip the test - syslog isn't available on this platform
  end

  def test_should_pass_and_log_exception
    e = Exception.new('exception')
    @logger.expects(:add).with(DEBUG, "message")
    @decorator.expects(:exception).with("Error details for message", e)
    @decorator.debug("message", e)
  end

  def test_should_not_ignore_infos
    1.step(5) { |i| @decorator.info(i) }
    assert_equal ['1', '2', '3', '4', '5'], @buffer.to_a.collect(&:message)
  end

  def test_should_ignore_debugs
    1.step(5) { |i| @decorator.debug(i) }
    assert_equal [], @buffer.to_a.collect(&:message)
  end

  def test_should_not_ignore_debugs
    @logger.level = DEBUG
    1.step(5) { |i| @decorator.debug(i) }
    assert_equal ['1', '2', '3', '4', '5'], @buffer.to_a.collect(&:message)
  end

  def test_should_keep_request_id_in_buffer_when_available
    request_id = '12345678'
    ::Logging.mdc['request'] = request_id
    @decorator.error('error message')

    assert_false @buffer.to_a.empty?
    assert_equal request_id, @buffer.to_a.first.request_id
  ensure
    ::Logging.mdc['request'] = nil
  end

  def test_should_roll_log_if_flag_is_set
    ::Proxy::LoggerFactory.stubs(:logger).returns(::Logger.new("/dev/null"))
    d = DecoratorForTesting.new(@logger, "/dev/null", @buffer)

    d.roll_log = true
    d.add(DEBUG)
    refute d.roll_log
  end
end
