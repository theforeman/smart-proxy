require 'proxy/log_buffer/buffer'

module Proxy::LogBuffer
  class Decorator
    def self.instance
      @@instance ||= new(::Proxy::LoggerFactory.logger, ::Proxy::LoggerFactory.log_file)
    end

    attr_accessor :formatter, :roll_log
    alias_method :roll_log?, :roll_log

    def initialize(logger, log_file, buffer = Proxy::LogBuffer::Buffer.instance)
      @logger = logger
      @buffer = buffer
      @log_file = log_file
      @mutex = Mutex.new
      self.roll_log = false
    end

    def add(severity, message = nil, progname = nil, exception_or_backtrace = nil)
      severity ||= UNKNOWN
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
        end
      end
      message = formatter.call(severity, Time.now.utc, progname, message) if formatter
      return if message == ''
      reopened = false
      @mutex.synchronize do
        if roll_log?
          # decorator is in-memory only, reopen underlaying logging appenders
          ::Logging.reopen
          self.roll_log = false
          reopened = true
        end
        # add to the logger first
        @logger.add(severity, message)
        # add add to the buffer
        if severity >= @logger.level
          # accepts backtrace, exception and simple string for historical reasons
          backtrace = if exception_or_backtrace.is_a?(Exception) && !exception_or_backtrace.backtrace.nil?
                        exception_or_backtrace.message + ': ' + exception_or_backtrace.backtrace.join("\n")
                      elsif backtrace.respond_to?(:join)
                        exception_or_backtrace.backtrace.join("\n")
                      else
                        exception_or_backtrace
                      end
          rec = Proxy::LogBuffer::LogRecord.new(nil, severity, message.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?'), backtrace, request_id)
          @buffer.push(rec)
        end
      end
      info("Logging file reopened via USR1 signal") if reopened
      # exceptions are also sent to structured log if available
      exception("Error details for #{message}", exception_or_backtrace) if exception_or_backtrace&.is_a?(Exception)
    end

    def trace?
      @trace ||= !!ENV['FOREMAN_PROXY_TRACE']
    end

    def trace(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::DEBUG, nil, msg_or_progname, exception_or_backtrace, &block) if trace?
    end

    def debug(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::DEBUG, nil, msg_or_progname, exception_or_backtrace, &block)
    end

    def info(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::INFO, nil, msg_or_progname, exception_or_backtrace, &block)
    end
    alias_method :write, :info

    def warn(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::WARN, nil, msg_or_progname, exception_or_backtrace, &block)
    end
    alias_method :warning, :warn

    def error(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::ERROR, nil, msg_or_progname, exception_or_backtrace, &block)
    end

    def fatal(msg_or_progname = nil, exception_or_backtrace = nil, &block)
      add(::Logger::Severity::FATAL, nil, msg_or_progname, exception_or_backtrace, &block)
    end

    def request_id
      (r = ::Logging.mdc['request']).nil? ? r : r.to_s[0..7]
    end

    # Structured fields to log in addition to log messages. Every log line created within given block is enriched with these fields.
    # Fields appear in joruand and/or JSON output (hash named 'ndc').
    def with_fields(fields = {})
      ::Logging.ndc.push(fields) do
        yield
      end
    end

    # Standard way for logging exceptions to get the most data in the log. By default
    # it logs via warn level, this can be changed via options[:level]
    def exception(context_message, exception, options = {})
      level = options[:level] || :warn
      unless ::Logging::LEVELS.key?(level.to_s)
        raise "Unexpected log level #{level}, expected one of #{::Logging::LEVELS.keys}"
      end
      # send class, message and stack as structured fields in addition to message string
      backtrace = exception.backtrace || []
      extra_fields = {
        exception_class: exception.class.name,
        exception_message: exception.message,
        exception_backtrace: backtrace,
      }
      extra_fields[:foreman_code] = exception.code if exception.respond_to?(:code)
      with_fields(extra_fields) do
        public_send(level) do
          (["#{context_message}: <#{exception.class}>: #{exception.message}"] + backtrace).join("\n")
        end
      end
    end

    # for Puma Event compatibility
    def sync=(_)
    end
    alias_method :log, :info
    alias_method :puts, :info

    def method_missing(symbol, *args)
      @logger.send(symbol, *args)
    end
  end
end
