module ::Proxy::PuppetCa
  class PluginConfiguration
    def load_classes
      require 'puppetca/puppetca_certmanager'
      require 'puppetca/dependency_injection'
      require 'puppetca/puppetca_api'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :cert_manager, lambda { ::Proxy::PuppetCa::Certmanager.new }
    end
  end
end
