module ::Proxy::Realm
  class ConfigurationLoader
    def load_classes
      require 'realm/dependency_injection'
      require 'realm/realm_api'
    end
  end
end
