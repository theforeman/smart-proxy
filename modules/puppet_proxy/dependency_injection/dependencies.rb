require 'puppet_proxy/runtime_configuration'

module Proxy::Puppet
  module DependencyInjection
    class Dependencies
      extend Proxy::Puppet::RuntimeConfiguration
      extend Proxy::Puppet::DependencyInjection::Wiring

      def self.puppet_parser_class(a_parser)
        case a_parser
        when :future_parser
          require 'puppet_proxy/class_scanner_eparser'
          ::Proxy::Puppet::ClassScannerEParser
        else
          require 'puppet_proxy/class_scanner'
          ::Proxy::Puppet::ClassScanner
        end
      end

      def self.environments_retriever_class(a_retriever)
        case a_retriever
        when :api_v3
          require 'puppet_proxy/puppet_api_v3_environments_retriever'
          ::Proxy::Puppet::PuppetApiV3EnvironmentsRetriever
        when :api_v2
          require 'puppet_proxy/puppet_api_v2_environments_retriever'
          ::Proxy::Puppet::PuppetApiV2EnvironmentsRetriever
        else
          require 'puppet_proxy/puppet_config_environments_retriever'
          ::Proxy::Puppet::PuppetConfigEnvironmentsRetriever
        end
      end

      dependency :puppet_class_scanner_impl, puppet_parser_class(puppet_parser)
      dependency :environments_retriever_impl, environments_retriever_class(environments_retriever)
      dependency :puppet_configuration_impl, Proxy::Puppet::PuppetConfig

      if Proxy::Puppet::Plugin.settings.use_cache
        require 'puppet_proxy/puppet_cache'
        singleton_dependency :puppet_cache_impl, Proxy::Puppet::PuppetCache
      else
        dependency :puppet_cache_impl, puppet_parser_class(puppet_parser)
      end
    end
  end
end
