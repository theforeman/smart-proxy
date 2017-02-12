module Proxy::ADRealm
  class ConfigurationLoader
    def load_classes
      require 'realm_ad/provider'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :realm_provider_impl,
                                    lambda {::Proxy::ADRealm::Provider.new(settings[:keytab_path], settings[:principal])}
    end
  end
end