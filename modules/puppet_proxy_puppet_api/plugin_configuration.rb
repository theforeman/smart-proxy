module ::Proxy::PuppetApi
  class PluginConfiguration
    def load_programmable_settings(settings)
      settings[:classes_retriever] = :apiv3
      settings[:environments_retriever] = :apiv3
      settings
    end

    def load_classes
      require 'puppet_proxy_common/errors'
      require 'puppet_proxy_common/environments_retriever_base'
      require 'puppet_proxy_common/environment'
      require 'puppet_proxy_common/puppet_class'
      require 'puppet_proxy_common/api_request'
      require 'puppet_proxy_puppet_api/v3_api_request'
      require 'puppet_proxy_puppet_api/v3_environments_retriever'
      require 'puppet_proxy_puppet_api/v3_environment_classes_api_classes_retriever'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :environment_retriever_impl,
                                    -> { ::Proxy::PuppetApi::V3EnvironmentsRetriever.new(settings[:puppet_url], settings[:puppet_ssl_ca], settings[:puppet_ssl_cert], settings[:puppet_ssl_key]) }

      container_instance.singleton_dependency :class_retriever_impl,
                                              (lambda do
                                                ::Proxy::PuppetApi::V3EnvironmentClassesApiClassesRetriever.new(
                                                  settings[:puppet_url],
                                                  settings[:puppet_ssl_ca],
                                                  settings[:puppet_ssl_cert],
                                                  settings[:puppet_ssl_key],
                                                  settings[:api_timeout])
                                              end)
      container_instance.dependency :class_cache_initializer,
                                    (lambda do
                                      Proxy::PuppetApi::EnvironmentClassesCacheInitializer.new(
                                        container_instance.get_dependency(:class_retriever_impl),
                                        container_instance.get_dependency(:environment_retriever_impl))
                                    end)
    end
  end
end
