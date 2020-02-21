module ::Proxy::PuppetCa::HostnameWhitelisting
  class PluginConfiguration
    def load_classes
      require 'puppetca_hostname_whitelisting/puppetca_hostname_whitelisting_autosigner'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :autosigner, -> { ::Proxy::PuppetCa::HostnameWhitelisting::Autosigner.new }
    end
  end
end

