require 'logger'

Logger.class_eval { alias_method :write, :'<<' } # ::Rack::CommonLogger expects loggers to implement 'write' method

module Proxy
  module Log
    @@logger = nil

    def logger
      return @@logger if @@logger
      @@logger = ::Proxy::Log.logger
    end

    def self.logger
      # We keep the last 6 10MB log files
      logger = ::Logger.new(::Proxy::SETTINGS.log_file, 6, 1024*1024*10)
      logger.level = ::Logger.const_get(::Proxy::SETTINGS.log_level.upcase)
      logger
    end
  end

  class LoggerMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env['rack.logger'] = ::Proxy::Log.logger
      @app.call(env)
    end
  end
end
