require 'rbconfig'

module Proxy::DHCP::ISC
  class PluginConfiguration
    def load_programmable_settings(settings)
      settings[:leases_file_observer] =
        case RbConfig::CONFIG['host_os']
        when /linux/
          :inotify_leases_file_observer
        when /bsd/
          :kqueue_leases_file_observer
        end
    end

    def load_dependency_injection_wirings(container, settings)
      container.dependency :memory_store, ::Proxy::MemoryStore
      container.singleton_dependency :subnet_service, (lambda do
        ::Proxy::DHCP::SubnetService.new(container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store))
      end)
      container.dependency :parser, lambda {::Proxy::DHCP::ISC::FileParser.new(container.get_dependency(:subnet_service))}
      container.dependency :config_file, lambda {::Proxy::DHCP::ISC::ConfigurationFile.new(settings[:config], container.get_dependency(:parser))}
      container.dependency :leases_file, lambda {::Proxy::DHCP::ISC::LeasesFile.new(settings[:leases], container.get_dependency(:parser))}
      container.dependency :state_changes_observer, (lambda do
        ::Proxy::DHCP::ISC::IscStateChangesObserver.new(container.get_dependency(:config_file), container.get_dependency(:leases_file), container.get_dependency(:subnet_service))
      end)

      if settings[:leases_file_observer] == :inotify_leases_file_observer
        require 'dhcp_isc/inotify_leases_file_observer'
        container.singleton_dependency :leases_observer, (lambda do
          ::Proxy::DHCP::ISC::InotifyLeasesFileObserver.new(container.get_dependency(:state_changes_observer), settings[:leases])
        end)
      elsif settings[:leases_file_observer] == :kqueue_leases_file_observer
        require 'dhcp_isc/kqueue_leases_file_observer'
        container.singleton_dependency :leases_observer, (lambda do
          ::Proxy::DHCP::ISC::KqueueLeasesFileObserver.new(container.get_dependency(:state_changes_observer), settings[:leases])
        end)
      end

      container.dependency :dhcp_provider, (lambda do
        Proxy::DHCP::ISC::Provider.new(
            settings[:server], settings[:omapi_port], settings[:subnets], settings[:key_name], settings[:key_secret],
            container.get_dependency(:subnet_service))
      end)
    end

    def load_classes
      require 'dhcp_common/subnet_service'
      require 'dhcp_common/server'
      require 'dhcp_isc/isc_file_parser'
      require 'dhcp_isc/configuration_file'
      require 'dhcp_isc/leases_file'
      require 'dhcp_isc/isc_state_changes_observer'
      require 'dhcp_isc/dhcp_isc_main'
    end
  end
end
