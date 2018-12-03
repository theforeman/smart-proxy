class Proxy::ProtectedRootApi < Sinatra::Base
  helpers ::Proxy::Helpers

  authorize_with_trusted_hosts
  authorize_with_ssl_client

  get "/v2/features" do
    begin

      enabled_plugins = ::Proxy::Plugins.instance.select do |plugin|
        plugin[:name] != :foreman_proxy && \
          plugin[:class].ancestors.include?(::Proxy::Plugin)
      end
      content_type :json

      attributes = %i[http_enabled https_enabled settings state]

      plugins = enabled_plugins.inject({}) do |hash, plugin|
        result = Hash[attributes.map { |attribute| [attribute, plugin[attribute]] }]
        result[:capabilities] = process_capabilities(plugin[:state], plugin[:capabilities])
        hash[plugin[:name]] = result
        hash
      end

      plugins.to_json
    rescue => e
      log_halt 500, e
    end
  end

  def process_capabilities(state, capabilities)
    capabilities = capabilities.select{|cap| !cap.is_a?(Proc) || state == :running }
    capabilities = capabilities.map do |capability|
      capability.is_a?(Proc) ? capability.call : capability
    end
    capabilities.flatten.compact
  end

end
