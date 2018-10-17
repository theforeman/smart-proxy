module ::Proxy::PuppetCa
  class PluginConfiguration
    def load_classes
      require 'puppetca/dependency_injection'
      require 'puppetca/puppetca_api'
    end

    def load_programmable_settings(settings)
      raise ::Proxy::Error::ConfigurationError, "Parameter ':puppet_version' is expected to have a non-empty value" if settings[:puppet_version].to_s.empty?

      use_provider = settings[:use_provider]
      use_provider = [use_provider].compact unless use_provider.is_a?(Array)
      use_provider << (Gem::Version.new(settings[:puppet_version].to_s) >= Gem::Version.new('6.0') ? :puppetca_http_api : :puppetca_puppet_cert)
      settings[:use_provider] = use_provider

      settings
    end
  end
end
