require 'logging'
require 'proxy/log_buffer/decorator'
require 'proxy/time_utils'

module Proxy
  module Log
    def logger
      ::Proxy::LogBuffer::Decorator.instance
    end
  end

  class LoggerFactory
    BASE_LOG_SIZE = 1024 * 1024 # 1 MiB

    begin
      require 'syslog/logger'
      @syslog_available = true
    rescue LoadError
      @syslog_available = false
    end

    def self.logger
      logger_name = 'foreman-proxy'
      layout = Logging::Layouts.pattern(pattern: ::Proxy::SETTINGS.file_logging_pattern + "\n")
      notime_layout = Logging::Layouts.pattern(pattern: ::Proxy::SETTINGS.system_logging_pattern + "\n")
      logger = Logging.logger.root
      if log_file.casecmp('STDOUT').zero?
        if SETTINGS.daemon
          puts "Settings log_file=STDOUT and daemon=true cannot be used together"
          exit(1)
        end
        logger.add_appenders(Logging.appenders.stdout(logger_name, layout: layout))
      elsif log_file.casecmp('SYSLOG').zero?
        unless syslog_available?
          puts "Syslog is not supported on this platform, use STDOUT or a file"
          exit(1)
        end
        logger.add_appenders(Logging.appenders.syslog(
          logger_name, layout: notime_layout, facility: ::Syslog::Constants::LOG_LOCAL5))
      elsif log_file.casecmp('JOURNAL').zero? || log_file.casecmp('JOURNALD').zero?
        begin
          logger.add_appenders(Logging.appenders.journald(
            logger_name, logger_name: :proxy_logger, layout: notime_layout, facility: ::Syslog::Constants::LOG_LOCAL5))
        rescue NoMethodError
          logger.add_appenders(Logging.appenders.stdout(logger_name, layout: layout))
          logger.warn "Journald is not available on this platform. Falling back to STDOUT."
        end
      else
        begin
          keep = ::Proxy::SETTINGS.file_rolling_keep
          size = BASE_LOG_SIZE * ::Proxy::SETTINGS.file_rolling_size
          age = ::Proxy::SETTINGS.file_rolling_age
          if size > 0
            logger.add_appenders(Logging.appenders.rolling_file(logger_name, layout: layout, filename: log_file, keep: keep, size: size, age: age, roll_by: 'date'))
          else
            logger.add_appenders(Logging.appenders.file(logger_name, layout: layout, filename: log_file))
          end
        rescue ArgumentError => ae
          logger.add_appenders(Logging.appenders.stdout(logger_name, layout: layout))
          logger.warn "Log file #{log_file} cannot be opened. Falling back to STDOUT: #{ae}"
        end
      end
      logger.level = ::Logging.level_num(::Proxy::SETTINGS.log_level)
      logger
    end

    def self.syslog_available?
      !!@syslog_available
    end

    def self.log_file
      @log_file ||= ::Proxy::SETTINGS.log_file
    end
  end

  class LoggerMiddleware
    include Log
    include ::Proxy::TimeUtils

    def initialize(app)
      @app = app
      @max_body_size = ENV['FOREMAN_LOG_MAX_BODY_SIZE'] || 2000
    end

    def call(env)
      before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status = 500
      env['rack.logger'] = logger
      logger.info { "Started #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} #{env['QUERY_STRING']}" }
      logger.trace { 'Headers: ' + env.select { |k, v| k.start_with? 'HTTP_' }.inspect }
      logger.trace do
        if env['rack.input'] && !(body = env['rack.input'].read).empty?
          env['rack.input'].rewind
          if env['CONTENT_TYPE'] == 'application/json' && body.size < @max_body_size
            "Body: #{body}"
          else
            "Body: [unknown content type or body too large - filtered out]"
          end
        else
          ''
        end
      end
      status, _, _ = @app.call(env)
    rescue Exception => e
      logger.exception "Error processing request '#{::Logging.mdc['request']}", e
      raise e
    ensure
      logger.info do
        after = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration = (after - before) * 1000
        "Finished #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} with #{status} (#{duration.round(2)} ms)"
      end
    end
  end
end
