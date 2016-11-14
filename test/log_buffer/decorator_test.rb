require 'test_helper'

class DecoratorTest < Test::Unit::TestCase
  class DecoratorForTesting < ::Proxy::LogBuffer::Decorator
    attr_reader :logger
  end

  SIZE = 10
  SIZE_TAIL = 5

  DEBUG = ::Logger::Severity::DEBUG
  INFO = ::Logger::Severity::INFO
  ERR = ::Logger::Severity::ERROR
  FATAL = ::Logger::Severity::FATAL

  def setup
    @buffer = Proxy::LogBuffer::Buffer.new(SIZE, SIZE_TAIL, ERR)
    @logger = ::Logger.new("/dev/null")
    @logger.level = INFO
    @decorator = ::Proxy::LogBuffer::Decorator.new(@logger, "STDOUT", @buffer)
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
  rescue LoadError # rubocop:disable Lint/HandleExceptions
    # skip the test - syslog isn't available on this platform
  end

  def test_should_pass_and_log_exception
    e = Exception.new('exception')
    @logger.expects(:add).with(DEBUG, "message")
    @logger.expects(:add).with(DEBUG, e)
    @decorator.debug("message", e)
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

  def test_should_keep_request_id_in_buffer_when_available
    request_id = '12345678'
    Thread.current.thread_variable_set(:request_id, request_id)
    @decorator.error('error message')

    assert_false @buffer.to_a.empty?
    assert_equal request_id, @buffer.to_a.first.request_id
  ensure
    Thread.current.thread_variable_set(:request_id, nil)
  end

  def test_should_not_roll_log_if_stdout_is_used
    ::Proxy::LoggerFactory.stubs(:logger).returns(::Logger.new("/dev/null"))
    (d = DecoratorForTesting.new(@logger, "STDOUT", nil)).handle_log_rolling
    assert_equal @logger, d.logger
  end

  def test_should_not_roll_log_if_syslog_is_used
    ::Proxy::LoggerFactory.stubs(:logger).returns(::Logger.new("/dev/null"))
    (d = DecoratorForTesting.new(@logger, "SYSLOG", nil)).handle_log_rolling
    assert_equal @logger, d.logger
  end

  def test_should_roll_log_if_file_logger_is_used
    ::Proxy::LoggerFactory.stubs(:logger).returns(::Logger.new("/dev/null"))
    (d = DecoratorForTesting.new(@logger, "/dev/null", nil)).handle_log_rolling
    assert_not_equal @logger, d.logger
  end

  def test_should_roll_log_if_flag_is_set
    ::Proxy::LoggerFactory.stubs(:logger).returns(::Logger.new("/dev/null"))
    d = DecoratorForTesting.new(@logger, "/dev/null", @buffer)

    d.roll_log
    d.add(DEBUG)

    assert_not_equal @logger, d.logger
  end
end
