module Proxy::DHCP
  class ConfigurationLoader
    def load_classes
      require 'dhcp/dependency_injection'
      require 'dhcp/dhcp_api'
    end
  end
end
