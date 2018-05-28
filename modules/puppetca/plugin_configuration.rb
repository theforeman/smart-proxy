module ::Proxy::PuppetCa
  class PluginConfiguration
    def load_classes
      require 'puppetca/puppetca_puppet_cert'
      require 'puppetca/dependency_injection'
      require 'puppetca/puppetca_api'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :puppet_cert, lambda { ::Proxy::PuppetCa::PuppetCert.new }
    end
  end
end
