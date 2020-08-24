module ::Proxy::Puppet
  class ConfigurationLoader
    def load_programmable_settings(settings)
      settings[:use_provider] = [:puppet_proxy_puppet_api]
      settings
    end

    def load_classes
      require 'puppet_proxy_common/errors'
      require 'puppet_proxy/dependency_injection'
      require 'puppet_proxy/puppet_api'
    end
  end
end
