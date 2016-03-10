require 'proxy/log_buffer/decorator'
require 'proxy/log_buffer/buffer'
require 'thread'

module Proxy::LogBuffer
  class Decorator
    def self.instance
      @@instance ||= new(::Proxy::LoggerFactory.logger, ::Proxy::LoggerFactory.log_file)
    end

    def initialize(logger, log_file, buffer = Proxy::LogBuffer::Buffer.instance)
      @logger = logger
      @buffer = buffer
      @log_file = log_file
      @mutex = Mutex.new
      @roll_log = false
    end

    # due to synchronization can't re-open the log from the signal trap
    def roll_log
      @roll_log = true
    end

    def handle_log_rolling
      return if @log_file.casecmp('STDOUT') == 0 || @log_file.casecmp('SYSLOG') == 0
      @roll_log = false
      @logger.close rescue nil
      @logger = ::Proxy::LoggerFactory.logger
    end

    def add(severity, message = nil, progname = nil, backtrace = nil)
      @mutex.synchronize do
        handle_log_rolling if @roll_log
        severity ||= UNKNOWN
        if message.nil?
          if block_given?
            message = yield
          else
            message = progname
          end
        end
        # add to the logger first
        @logger.add(severity, message)
        @logger.add(::Logger::Severity::DEBUG, backtrace) if backtrace
        # add add to the buffer
        if severity >= @logger.level
          # we accept backtrace, exception and simple string
          backtrace = backtrace.is_a?(Exception) ? backtrace.backtrace : backtrace
          backtrace = backtrace.respond_to?(:join) ? backtrace.join("\n") : backtrace
          rec = Proxy::LogBuffer::LogRecord.new(nil, severity, message, backtrace)
          @buffer.push(rec)
        end
      end
    end

    def debug(msg_or_progname, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::DEBUG, nil, msg_or_progname, exception_or_backtrace, &block)
    end

    def info(msg_or_progname, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::INFO, nil, msg_or_progname, exception_or_backtrace, &block)
    end
    alias_method :write, :info

    def warn(msg_or_progname, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::WARN, nil, msg_or_progname, exception_or_backtrace, &block)
    end
    alias_method :warning, :warn

    def error(msg_or_progname, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::ERROR, nil, msg_or_progname, exception_or_backtrace, &block)
    end

    def fatal(msg_or_progname, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::FATAL, nil, msg_or_progname, exception_or_backtrace, &block)
    end

    def method_missing(symbol, *args);
      @logger.send(symbol, *args)
    end
  end
end
