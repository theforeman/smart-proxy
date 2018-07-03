class Proxy::RootApi < Sinatra::Base
  helpers ::Proxy::Helpers

  get "/features" do
    begin
      enabled_plugins = ::Proxy::Plugins.instance.select {|p| p[:state] == :running && p[:class].ancestors.include?(::Proxy::Plugin)}
      enabled_plugin_names = (enabled_plugins.map {|p| p[:name].to_s} - ['foreman_proxy']).sort
      content_type :json
      enabled_plugin_names.to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/v2/features" do
    begin
      enabled_plugins = ::Proxy::Plugins.instance.select do |p|
        p[:name] != :foreman_proxy && \
          p[:state] == :running && \
          p[:class].ancestors.include?(::Proxy::Plugin)
      end
      content_type :json
      enabled_plugins.sort { |x, y| x[:name] <=> y[:name] }.map do |p|
        {
          'name' => p[:name],
          'capabilities' => p[:capabilities],
          'http_enabled' => p[:http_enabled],
          'https_enabled' => p[:https_enabled],
          'settings' => p[:settings],
        }
      end.to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/version" do
    begin
      content_type :json
      enabled_plugins = ::Proxy::Plugins.instance.select {|p| p[:state] == :running && p[:class].ancestors.include?(::Proxy::Plugin)}
      modules = Hash[enabled_plugins.map {|plugin| [plugin[:name].to_s, plugin[:version].to_s]}].reject { |key| key == 'foreman_proxy' }
      {:version => Proxy::VERSION, :modules => modules}.to_json
    rescue => e
      log_halt 400, e
    end
  end
end
