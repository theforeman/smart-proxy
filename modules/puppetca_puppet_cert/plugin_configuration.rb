module Proxy
  module PuppetCa
    module PuppetcaPuppetCert
      class PluginConfiguration
        def load_classes
          require 'puppetca_puppet_cert/puppetca_impl'
        end

        def load_dependency_injection_wirings(container_instance, settings)
          container_instance.dependency :puppetca_impl, lambda { ::Proxy::PuppetCa::PuppetcaPuppetCert::PuppetcaImpl.new }
        end
      end
    end
  end
end
