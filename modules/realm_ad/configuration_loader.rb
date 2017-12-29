module Proxy::AdRealm
  class ConfigurationLoader
    def load_classes
      require 'realm_ad/provider'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :realm_provider_impl,
                                    lambda {
                                      ::Proxy::AdRealm::Provider.new(
                                        realm: settings[:realm],
                                        keytab_path: settings[:keytab_path],
                                        principal: settings[:principal],
                                        domain_controller: settings[:domain_controller],
                                        ou: settings[:ou],
                                        computername_prefix: settings[:computername_prefix],
                                        computername_hash: settings[:computername_hash],
                                        computername_use_fqdn: settings[:computername_use_fqdn]
                                      )
                                    }
    end
  end
end
