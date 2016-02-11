module Proxy::Puppet
  module DependencyInjection
    class Dependencies
      extend Proxy::Puppet::RuntimeConfiguration
      extend Proxy::Puppet::DependencyInjection::Wiring

      settings = Proxy::Puppet::Plugin.settings

      case environments_retriever
      when :api_v3
        require 'puppet_proxy/puppet_api_v3_environments_retriever'
        dependency :environment_retriever_impl,
                   lambda {|c| ::Proxy::Puppet::PuppetApiV3EnvironmentsRetriever.new(settings.puppet_url, settings.puppet_ssl_ca, settings.puppet_ssl_cert, settings.puppet_ssl_key)}
      when :api_v2
        require 'puppet_proxy/puppet_api_v2_environments_retriever'
        dependency :environment_retriever_impl,
                   lambda {|c| ::Proxy::Puppet::PuppetApiV2EnvironmentsRetriever.new(settings.puppet_url, settings.puppet_ssl_ca, settings.puppet_ssl_cert, settings.puppet_ssl_key)}
      else
        require 'puppet_proxy/puppet_config_environments_retriever'
        dependency :puppet_configuration, Proxy::Puppet::PuppetConfig
        dependency :environment_retriever_impl, lambda {|c| ::Proxy::Puppet::PuppetConfigEnvironmentsRetriever.new(c.get_dependency(:puppet_configuration))}
      end

      case classes_retriever
        when :api_v3
          require 'puppet_proxy/puppet_api_v3_classes_retriever'
          dependency :class_retriever_impl,
                     lambda {|c| ::Proxy::Puppet::PuppetApiV3ClassesRetriever.new(settings.puppet_url, settings.puppet_ssl_ca, settings.puppet_ssl_cert, settings.puppet_ssl_key)}
        when :cached_future_parser
          require 'puppet_proxy/class_scanner_eparser'
          require 'puppet_proxy/puppet_cache'
          singleton_dependency :class_retriever_impl, lambda {|c| ::Proxy::Puppet::PuppetCache.new(c.get_dependency(:environment_retriever_impl), ::Proxy::Puppet::ClassScannerEParser.new(nil))}
        when :cached_legacy_parser
          require 'puppet_proxy/class_scanner'
          require 'puppet_proxy/puppet_cache'
          singleton_dependency :class_retriever_impl, lambda {|c| ::Proxy::Puppet::PuppetCache.new(c.get_dependency(:environment_retriever_impl), ::Proxy::Puppet::ClassScanner.new(nil))}
        when :future_parser
          require 'puppet_proxy/class_scanner_eparser'
          dependency :class_retriever_impl, ::Proxy::Puppet::ClassScannerEParser
        else
          require 'puppet_proxy/class_scanner'
          dependency :class_retriever_impl, ::Proxy::Puppet::ClassScanner
      end
    end
  end
end
