module ::Proxy::PuppetCa
  class PluginConfiguration
    def load_classes
      require 'puppetca/dependency_injection'
      require 'puppetca/puppetca_api'
    end

    def load_programmable_settings(settings)
      use_provider = settings[:use_provider]
      use_provider = [use_provider].compact unless use_provider.is_a?(Array)
      use_provider << :puppetca_http_api
      settings[:use_provider] = use_provider

      settings
    end
  end
end
