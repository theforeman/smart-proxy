class Proxy::RootV2Api < Sinatra::Base
  helpers ::Proxy::Helpers

  authorize_with_trusted_hosts
  authorize_with_ssl_client

  get "/features" do
    enabled_plugins = ::Proxy::Plugins.instance.select do |plugin|
      plugin[:name] != :foreman_proxy && \
        plugin[:class].ancestors.include?(::Proxy::Plugin)
    end
    content_type :json

    attributes = [:http_enabled, :https_enabled, :settings, :state]

    plugins = enabled_plugins.each_with_object({}) do |plugin, hash|
      result = Hash[attributes.map { |attribute| [attribute, plugin[attribute]] }]
      result[:capabilities] = process_capabilities(plugin[:state], plugin[:capabilities])
      hash[plugin[:name]] = result
    end

    plugins.to_json
  rescue => e
    log_halt 500, e
  end

  def process_capabilities(state, capabilities)
    return [] if capabilities.nil?
    capabilities = capabilities.select { |cap| !cap.is_a?(Proc) || state == :running }
    capabilities = capabilities.map do |capability|
      capability.is_a?(Proc) ? capability.call : capability
    end
    capabilities.flatten.uniq.compact.sort
  end
end
