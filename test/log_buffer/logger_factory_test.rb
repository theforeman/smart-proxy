require 'test_helper'
require 'tempfile'
require 'proxy/log'

class LoggerFactoryTest < Test::Unit::TestCase
  def setup
    @factory = ::Proxy::LoggerFactory
  end

  def test_should_configure_logger_when_stdout_is_used
    @factory.stubs(:log_file).returns('STDOUT')
    logger = @factory.logger

    assert logger.is_a?(::Logger)
    assert logger.formatter.is_a?(::Proxy::LoggerFactory::LogFormatter)
  end

  def test_should_configure_logger_by_default
    tmp_logfile = Tempfile.new('logfactory-test').path
    @factory.stubs(:log_file).returns(tmp_logfile)
    logger = @factory.logger

    assert logger.is_a?(::Logger)
    assert logger.formatter.is_a?(::Proxy::LoggerFactory::LogFormatter)
  end

  def test_should_configure_syslog
    @factory.stubs(:log_file).returns('SYSLOG')
    @factory.expects(:syslog_available?).returns(true)
    logger = @factory.logger

    assert logger.is_a?(::Syslog::Logger)
    assert logger.formatter.is_a?(::Proxy::LoggerFactory::SyslogFormatter)
  end
end
