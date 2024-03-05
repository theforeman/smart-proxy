module ::Proxy::Ipam
  class ConfigurationLoader
    def load_classes
      require 'externalipam/dependency_injection'
      require 'externalipam/ipam_api'
    end
  end
end
