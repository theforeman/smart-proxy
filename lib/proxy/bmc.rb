require 'proxy/bmc/ipmi'

module Proxy
  module BMC

    # This is a top level function to list all providers accepted
    def self.installed_providers?
      IPMI.providers_installed?
    end

    def self.providers
      IPMI.providers
    end

    def self.installed?(provider)
      IPMI.installed?(provider)
    end
 end
end
