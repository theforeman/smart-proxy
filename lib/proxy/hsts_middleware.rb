module Proxy
  # Add the HSTS header if not present. This header is entirely useless for us
  # because the header is aimed at browsers, but some scanners still think this
  # is needed.
  # https://www.tenable.com/plugins/nessus/142960
  class HstsMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      if env['HTTPS'] == 'on' && !headers.include?('Strict-Transport-Security')
        headers['Strict-Transport-Security'] = 'max-age=31536000'
      end
      [status, headers, body]
    end
  end
end
