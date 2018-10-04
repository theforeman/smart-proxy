module Proxy
  class RequestIdMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      ::Logging.mdc['remote_ip'] = env['REMOTE_ADDR']
      if env.has_key?('HTTP_X_REQUEST_ID')
        ::Logging.mdc['request'] = env['HTTP_X_REQUEST_ID']
      else
        ::Logging.mdc['request'] = SecureRandom.uuid
      end
      status, header, body = @app.call(env)
      [status, header, ::Rack::BodyProxy.new(body) { ::Logging.mdc.clear }]
    end
  end
end
