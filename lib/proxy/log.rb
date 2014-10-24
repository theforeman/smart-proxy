require 'logger'

Logger.class_eval { alias_method :write, :'<<' } # ::Rack::CommonLogger expects loggers to implement 'write' method

module Proxy
  module Log
    @@logger = nil

    def logger
      @@logger ||= ::Proxy::Log.logger
    end

    def self.logger
      log_file = ::Proxy::SETTINGS.log_file
      if log_file.upcase == 'STDOUT'
        logger = ::Logger.new(STDOUT)
      else
        # We keep the last 6 10MB log files
        logger = ::Logger.new(log_file, 6, 1024*1024*10)
      end
      logger.level = ::Logger.const_get(::Proxy::SETTINGS.log_level.upcase)
      logger
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
