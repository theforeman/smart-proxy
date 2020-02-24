require 'proxy/log_buffer/buffer'

module Proxy::LogBuffer
  class TraceDecorator
    def self.instance
      @@instance ||= new(::Proxy::LogBuffer::Decorator.instance)
    end

    def initialize(logger)
      @logger = logger
    end

    def debug(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      @logger.trace(msg_or_progname, exception_or_backtrace, &block)
    end

    def info(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      @logger.trace(msg_or_progname, exception_or_backtrace, &block)
    end

    def warn(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      @logger.trace(msg_or_progname, exception_or_backtrace, &block)
    end

    def error(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      @logger.trace(msg_or_progname, exception_or_backtrace, &block)
    end

    def fatal(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      @logger.trace(msg_or_progname, exception_or_backtrace, &block)
    end

    def method_missing(symbol, *args);
      @logger.send(symbol, *args)
    end
  end
end
