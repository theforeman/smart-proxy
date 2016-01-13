require 'proxy/events/buffer'

module Proxy::Events
  class LogDecorator
    def initialize(logger)
      @logger = logger
    end

    def add(severity, message = nil, progname = nil, backtrace = nil, &block)
      severity ||= UNKNOWN
      progname ||= @logger.progname
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = @logger.progname
        end
      end
      # we accept backtrace, exception and simple string
      backtrace = backtrace.is_a?(Exception) ? backtrace.backtrace : backtrace
      backtrace = backtrace.respond_to?(:join) ? backtrace.join("\n") : backtrace
      if backtrace
        an_event = Proxy::Events::BacktraceLogEvent.new(nil, Time.now.utc.to_i, severity, message, backtrace)
      else
        an_event = Proxy::Events::LogEvent.new(nil, Time.now.utc.to_i, severity, message)
      end
      Proxy::Events::Buffer.instance.push(an_event)
      @logger.add(severity, message, progname)
      @logger.add(::Logger::Severity::DEBUG, backtrace) if backtrace
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
