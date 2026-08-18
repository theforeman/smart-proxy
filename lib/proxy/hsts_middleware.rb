module Proxy
  # Add the HSTS header if not present. This header is entirely useless for us
  # because the header is aimed at browsers, but some scanners still think this
  # is needed.
  # https://www.tenable.com/plugins/nessus/142960
  class HstsMiddleware
    # Lowercase is required by Rack 3 (https://github.com/rack/rack/issues/1592);
    # Rack 2 doesn't care about header key case, so this works for both.
    HEADER_KEY = 'strict-transport-security'.freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      if env['HTTPS'] == 'on' && !headers.include?(HEADER_KEY)
        headers[HEADER_KEY] = 'max-age=31536000'
      end
      [status, headers, body]
    end
  end
end
