module Proxy::ADRealm
  class ConfigurationLoader
    def load_classes
      require 'realm_ad/provider'
    end
    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :realm_provider_impl,
                                    lambda {
                                      ::Proxy::ADRealm::Provider.new(
                                        settings[:realm],
                                        settings[:keytab_path],
                                        settings[:principal],
                                        settings[:domain_controller],
                                        settings[:ldap_user],
                                        settings[:ldap_password],
                                        settings[:ldap_port]) }
    end
  end
end