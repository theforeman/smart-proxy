module Proxy
  class RequestIdMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      ::Logging.mdc['remote_ip'] = env['REMOTE_ADDR']
      ::Logging.mdc['request'] = env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid
      ::Logging.mdc['session'] = env['HTTP_X_SESSION_ID'] || SecureRandom.uuid
      status, header, body = @app.call(env)
      [status, header, ::Rack::BodyProxy.new(body) { ::Logging.mdc.clear }]
    end
  end
end
