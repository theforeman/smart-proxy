module Proxy
  class RequestIdMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Thread.current.thread_variable_set(:request_id, env['HTTP_X_REQUEST_ID']) if env.has_key?('HTTP_X_REQUEST_ID')
      status, header, body = @app.call(env)
      [status, header, ::Rack::BodyProxy.new(body) { Thread.current.thread_variable_set(:request_id, nil) }]
    end
  end
end
