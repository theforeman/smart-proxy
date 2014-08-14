class Proxy::RootApi < Sinatra::Base
  helpers ::Proxy::Helpers
  authorize_with_trusted_hosts

  get "/features" do
    begin
      plugin_names = ::Proxy::Plugins.enabled_plugins.collect(&:plugin_name).collect(&:to_s).sort

      @features = plugin_names - ['foreman_proxy']
      if request.accept? 'application/json'
        content_type :json
        @features.to_json
      else
        erb :"features/index"
      end
    rescue => e
      log_halt 400, e
    end
  end

  get "/version" do
    begin
      {:version => Proxy::VERSION}.to_json
    rescue => e
      log_halt 400, e
    end
  end
end
