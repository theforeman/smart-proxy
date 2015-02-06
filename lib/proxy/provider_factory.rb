class ::Proxy::ProviderFactory
  class << self
    def get_provider(provider_name, opts)
      provider = ::Proxy::Plugins.find_provider(provider_name.to_sym)
      provider.provider_factory.call(opts)
    end
  end
end
