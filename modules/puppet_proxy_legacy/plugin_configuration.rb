require 'proxy/util'

module ::Proxy::PuppetLegacy
  class PluginConfiguration
    include Proxy::Util

    def load_programmable_settings(settings)
      puppet_conf_exists?(settings[:puppet_conf])
      puppet_configuration = load_puppet_configuration(settings[:puppet_conf])

      use_future_parser = use_future_parser?(puppet_configuration)
      use_cache = !!settings[:use_cache]

      settings[:classes_retriever] = if use_cache && use_future_parser
                                       :cached_future_parser
                                     elsif use_cache && !use_future_parser
                                       :cached_legacy_parser
                                     elsif !use_cache && use_future_parser
                                       :future_parser
                                     else
                                       :legacy_parser
                                     end

      force = to_bool(settings[:use_environment_api], nil)
      settings[:environments_retriever] = if settings[:puppet_version].to_s < '3.2'
                                            :config_file
                                          elsif !force.nil? && force
                                            :api_v2
                                          elsif !force.nil? && !force
                                            :config_file
                                          else
                                            use_environment_api?(puppet_configuration) ? :api_v2 : :config_file
                                          end

      settings
    end

    def load_classes
      require 'puppet_proxy_common/custom_validators'
      require 'puppet_proxy_legacy/puppet_config'
      require 'puppet_proxy_common/errors'
      require 'puppet_proxy_common/environments_retriever_base'
      require 'puppet_proxy_legacy/class_scanner_base'
      require 'puppet_proxy_common/environment'
      require 'puppet_proxy_common/puppet_class'
      require 'puppet_proxy_common/api_request'

      require 'puppet'
      require 'puppet_proxy_legacy/initializer'
      require 'puppet_proxy_legacy/environments_api_request'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      case settings[:environments_retriever]
        when :api_v2
          require 'puppet_proxy_legacy/puppet_api_v2_environments_retriever'
          container_instance.dependency :environment_retriever_impl, (lambda do
            ::Proxy::PuppetLegacy::PuppetApiV2EnvironmentsRetriever.new(settings[:puppet_url], settings[:puppet_ssl_ca], settings[:puppet_ssl_cert], settings[:puppet_ssl_key])
          end)
        else
          require 'puppet_proxy_legacy/puppet_config_environments_retriever'
          container_instance.dependency :puppet_configuration,  lambda {Proxy::PuppetLegacy::ConfigReader.new(settings[:puppet_conf])}
          container_instance.dependency :environment_retriever_impl, (lambda do
            ::Proxy::PuppetLegacy::PuppetConfigEnvironmentsRetriever.new(container_instance.get_dependency(:puppet_configuration), settings[:puppet_conf])
          end)
      end

      container_instance.dependency :puppet_initializer, lambda {Proxy::PuppetLegacy::Initializer.new(settings[:puppet_conf]) }

      case settings[:classes_retriever]
        when :cached_future_parser
          require 'puppet_proxy_legacy/class_scanner_eparser'
          require 'puppet_proxy_legacy/puppet_cache'
          container_instance.singleton_dependency :class_retriever_impl, (lambda do
            ::Proxy::PuppetLegacy::PuppetCache.new(
                container_instance.get_dependency(:environment_retriever_impl),
                ::Proxy::PuppetLegacy::ClassScannerEParser.new(nil, container_instance.get_dependency(:puppet_initializer)))
          end)
        when :cached_legacy_parser
          require 'puppet_proxy_legacy/class_scanner'
          require 'puppet_proxy_legacy/puppet_cache'
          container_instance.singleton_dependency :class_retriever_impl, (lambda do
            ::Proxy::PuppetLegacy::PuppetCache.new(
                container_instance.get_dependency(:environment_retriever_impl),
                ::Proxy::PuppetLegacy::ClassScanner.new(nil, container_instance.get_dependency(:puppet_initializer)))
          end)
        when :future_parser
          require 'puppet_proxy_legacy/class_scanner_eparser'
          container_instance.dependency :class_retriever_impl, (lambda do
            ::Proxy::PuppetLegacy::ClassScannerEParser.new(
                container_instance.get_dependency(:environment_retriever_impl),
                container_instance.get_dependency(:puppet_initializer))
          end)
        else
          require 'puppet_proxy_legacy/class_scanner'
          container_instance.dependency :class_retriever_impl, (lambda do
            ::Proxy::PuppetLegacy::ClassScanner.new(
                container_instance.get_dependency(:environment_retriever_impl),
                container_instance.get_dependency(:puppet_initializer))
          end)
      end
    end

    def puppet_conf_exists?(path)
      raise ::Proxy::Error::ConfigurationError, "Puppet configuration file '#{path}' defined in ':puppet_conf' setting doesn't exist or is unreadable" unless File.readable?(path)
    end

    def use_future_parser?(puppet_config)
      (puppet_config[:main] && puppet_config[:main][:parser] == 'future') ||
          (puppet_config[:master] && puppet_config[:master][:parser] == 'future')
    end

    def use_environment_api?(puppet_config)
      !([:main, :master].any? { |s| (puppet_config[s] && puppet_config[s][:environmentpath] && !puppet_config[s][:environmentpath].empty?) })
    end

    def load_puppet_configuration(config)
      @config ||= Proxy::PuppetLegacy::ConfigReader.new(config).get
    end
  end
end
