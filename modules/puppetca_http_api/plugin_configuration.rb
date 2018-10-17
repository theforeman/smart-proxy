module Proxy
  module PuppetCa
    module PuppetcaHttpApi
      class PluginConfiguration
        def load_classes
          require 'puppetca_http_api/puppetca_impl'
          require 'puppetca_http_api/ca_v1_api_request'
        end

        def load_dependency_injection_wirings(container_instance, settings)
          container_instance.dependency :puppetca_impl, lambda { ::Proxy::PuppetCa::PuppetcaHttpApi::PuppetcaImpl.new }
          container_instance.dependency :http_api_impl,
                                        lambda {
                                          ::Proxy::PuppetCa::PuppetcaHttpApi::CaApiv1Request.new(
                                            settings[:puppet_url],
                                            settings[:puppet_ssl_ca],
                                            settings[:puppet_ssl_cert],
                                            settings[:puppet_ssl_key]
                                          )
                                        }
        end
      end
    end
  end
end
