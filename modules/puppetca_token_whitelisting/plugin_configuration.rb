module ::Proxy::PuppetCa::TokenWhitelisting
  class PluginConfiguration
    def load_classes
      require 'puppetca_token_whitelisting/puppetca_token_whitelisting_autosigner'
      require 'puppetca_token_whitelisting/puppetca_token_whitelisting_csr'
      require 'puppetca_token_whitelisting/puppetca_token_whitelisting_token_storage'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :autosigner, -> { ::Proxy::PuppetCa::TokenWhitelisting::Autosigner.new }
    end
  end
end

