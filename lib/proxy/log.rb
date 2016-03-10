require 'logger'
require 'proxy/log_buffer/decorator'

begin
  require 'syslog/logger'
  ::Syslog::Logger.class_eval { alias_method :write, :info }
rescue LoadError # rubocop:disable Lint/HandleExceptions
  # ignore, syslog isn't available on this platform
end
# rubocop:enable Lint/HandleExceptions

# ::Rack::CommonLogger expects loggers to implement 'write' method
Logger.class_eval { alias_method :write, :info }

module Proxy
  module Log
    def logger
      ::Proxy::LogBuffer::Decorator.instance
    end
  end

  class LoggerFactory
    def self.logger
      if log_file.casecmp('STDOUT').zero?
        if SETTINGS.daemon
          puts "Settings log_file=STDOUT and daemon=true are incompatible, exiting..."
          exit 1
        end
        logger = ::Logger.new(STDOUT)
      elsif log_file.casecmp('SYSLOG').zero?
        begin
          logger = ::Syslog::Logger.new 'foreman-proxy'
        rescue
          logger = default_logger(log_file)
          puts "'SYSLOG' logger is not supported on this platform, using file-based logger instead"
        end
      else
        logger = default_logger(log_file)
      end
      logger.level = ::Logger.const_get(::Proxy::SETTINGS.log_level.upcase)
      logger
    end

    def self.default_logger(log_file)
      # We keep the last 6 10MB log files
      ::Logger.new(log_file, 6, 1024*1024*10)
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
