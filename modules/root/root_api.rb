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
