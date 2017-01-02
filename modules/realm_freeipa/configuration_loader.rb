module Proxy::FreeIPARealm
  class ConfigurationLoader
    def load_classes
      require 'realm_freeipa/ipa_config_parser'
      require 'realm_freeipa/provider'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :ipa_config, lambda { Proxy::FreeIPARealm::IpaConfigParser.new(settings[:ipa_config]) }
      container_instance.dependency :realm_provider_impl,
                                    lambda {::Proxy::FreeIPARealm::Provider.new(container_instance.get_dependency(:ipa_config), settings[:keytab_path], settings[:principal], settings[:remove_dns])}
    end
  end
end
