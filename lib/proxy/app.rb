module Proxy
  class App
    def initialize(plugins)
      @apps = {}

      http_plugins = plugins.select { |p| p[:state] == :running && p[:http_enabled] }
      if http_plugins.any?
        @apps['http'] = Rack::Builder.new do
          http_plugins.each { |p| instance_eval(p[:class].http_rackup) }
        end
      end

      https_plugins = plugins.select { |p| p[:state] == :running && p[:https_enabled] }
      if https_plugins.any?
        @apps['https'] = Rack::Builder.new do
          https_plugins.each { |p| instance_eval(p[:class].https_rackup) }
        end
      end
    end

    def call(env)
      # TODO: Respect X-Forwarded-Proto?
      scheme = env['rack.url_scheme']
      app = @apps[scheme]
      fail "Unsupported URL scheme #{scheme}" unless app
      app.call(env)
    end
  end
end
