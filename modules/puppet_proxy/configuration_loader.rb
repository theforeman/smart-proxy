module ::Proxy::Puppet
  class ConfigurationLoader
    def load_programmable_settings(settings)
      raise ::Proxy::Error::ConfigurationError, "Parameter ':puppet_version' is expected to have a non-empty value" if settings[:puppet_version].to_s.empty?

      use_provider = settings[:use_provider]
      use_provider = [use_provider].compact unless use_provider.is_a?(Array)
      use_provider << (settings[:puppet_version].to_s >= "4.0" ? :puppet_proxy_puppet_api : :puppet_proxy_legacy)
      settings[:use_provider] = use_provider

      settings
    end

    def load_classes
      require 'puppet_proxy_common/errors'
      require 'puppet_proxy/dependency_injection'
      require 'puppet_proxy/puppet_api'
    end
  end
end
