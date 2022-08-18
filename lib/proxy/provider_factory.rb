class ::Proxy::ProviderFactory
  extend ::Proxy::Log
  class << self
    def get_provider(provider_name, opts = {})
      logger.warn('Proxy::ProviderFactory class has been deprecated and will be removed in 3.5')
      provider = ::Proxy::Plugins.instance.find_provider(provider_name.to_sym)
      pf = provider.provider_factory
      pf.is_a?(Proc) ? pf.call(opts) : pf.new.get_provider(opts)
    end
  end
end
