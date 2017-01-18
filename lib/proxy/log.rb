require 'logger'
require 'proxy/log_buffer/decorator'

# ::Rack::CommonLogger expects loggers to implement 'write' method
Logger.class_eval { alias_method :write, :info }

module Proxy
  module Log
    def logger
      ::Proxy::LogBuffer::Decorator.instance
    end
  end

  class LoggerFactory
    class LogFormatter < ::Logger::Formatter
      Format = "%s, [%s%s] %5s -- %s: %s\n".freeze

      def call(severity, time, progname, msg)
        Format % [severity[0..0], format_datetime(time), request_id[0..7], severity, progname, msg2str(msg)]
      end

      def request_id
        Thread.current.thread_variable_get(:request_id).to_s
      end
    end

    begin
      require 'syslog/logger'
      ::Syslog::Logger.class_eval { alias_method :write, :info }

      class SyslogFormatter < Syslog::Logger::Formatter
        Format = "<%s> %s\n".freeze

        def call(severity, time, progname, msg)
          request_id.empty? ? clean(msg) : Format % [request_id[0..7], clean(msg)]
        end

        def request_id
          Thread.current.thread_variable_get(:request_id).to_s
        end
      end

      @syslog_available = true
    rescue LoadError
      # ignore, syslog isn't available on this platform
      @syslog_available = false
    end

    def self.logger
      if log_file.casecmp('STDOUT').zero?
        if SETTINGS.daemon
          puts "Settings log_file=STDOUT and daemon=true are incompatible, exiting..."
          exit(1)
        end
        logger = stdout_logger
      elsif log_file.casecmp('SYSLOG').zero?
        unless syslog_available?
          puts "'SYSLOG' logger is not supported on this platform, please use STDOUT or a file-based logger. Exiting..."
          exit(1)
        end
        logger = syslog_logger
      else
        logger = default_logger(log_file)
      end
      logger.level = ::Logger.const_get(::Proxy::SETTINGS.log_level.upcase)
      logger
    end

    def self.default_logger(log_file)
      # We keep the last 6 10MB log files
      logger = ::Logger.new(log_file, 6, 1024*1024*10)
      logger.formatter = LogFormatter.new
      logger
    rescue Exception => e
      puts "Unable to configure file-based logger: #{e.message}. Exiting..."
      exit(1)
    end

    def self.stdout_logger
      logger = ::Logger.new(STDOUT)
      logger.formatter = LogFormatter.new
      logger
    end

    def self.syslog_logger
      logger = ::Syslog::Logger.new 'foreman-proxy'
      logger.formatter = SyslogFormatter.new
      logger
    end

    def self.syslog_available?
      !!@syslog_available
    end

    def self.log_file
      ::Proxy::SETTINGS.log_file
    end
  end

  class LoggerMiddleware
    include Log

    def initialize(app)
      @app = app
    end

    def call(env)
      env['rack.logger'] = logger
      @app.call(env)
    end
  end
end
