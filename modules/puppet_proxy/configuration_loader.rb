module ::Proxy::Puppet
  class ConfigurationLoader
    def load_classes
      require 'puppet_proxy/errors'
      require 'puppet_proxy/dependency_injection'
      require 'puppet_proxy/puppet_api'
      require 'puppet_proxy/environment'
      require 'puppet_proxy/puppet_class'
      require 'puppet_proxy_common/api_request'
      require 'puppet_proxy/apiv3'
      require 'puppet_proxy/v3_environments_retriever'
      require 'puppet_proxy/v3_environment_classes_api_classes_retriever'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :environment_retriever_impl,
                                    (lambda do
                                       api = Proxy::Puppet::Apiv3.new(
                                         settings[:puppet_url],
                                         settings[:puppet_ssl_ca],
                                         settings[:puppet_ssl_cert],
                                         settings[:puppet_ssl_key])
                                       ::Proxy::Puppet::V3EnvironmentsRetriever.new(api)
                                     end)

      container_instance.singleton_dependency :class_retriever_impl,
                                              (lambda do
                                                 ::Proxy::Puppet::V3EnvironmentClassesApiClassesRetriever.new(
                                                   settings[:puppet_url],
                                                   settings[:puppet_ssl_ca],
                                                   settings[:puppet_ssl_cert],
                                                   settings[:puppet_ssl_key],
                                                   settings[:api_timeout])
                                               end)
    end
  end
end
