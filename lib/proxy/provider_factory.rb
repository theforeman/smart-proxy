class ::Proxy::ProviderFactory
  class << self
    def get_provider(provider_name, opts = {})
      provider = ::Proxy::Plugins.find_provider(provider_name.to_sym)
      pf = provider.provider_factory
      pf.is_a?(Proc) ? pf.call(opts) : pf.new.get_provider(opts)
    end
  end
end
