module ::Proxy::Dns
  class ConfigurationLoader
    def load_classes
      require 'dns_common/dns_common'
      require 'dns/dependency_injection'
      require 'dns/dns_api'
    end
  end
end
