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
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store))
      end)
      container.dependency :parser, -> {::Proxy::DHCP::CommonISC::ConfigurationParser.new}
      container.dependency :service_initialization, -> {::Proxy::DHCP::CommonISC::IscSubnetServiceInitialization.new(container.get_dependency(:subnet_service), container.get_dependency(:parser))}
      container.dependency :state_changes_observer, (lambda do
        ::Proxy::DHCP::ISC::IscStateChangesObserver.new(settings[:config], settings[:leases], container.get_dependency(:subnet_service), container.get_dependency(:service_initialization))
      end)

      container.singleton_dependency :free_ips, -> {::Proxy::DHCP::FreeIps.new(settings[:blacklist_duration_minutes]) }

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
        Proxy::DHCP::CommonISC::IscOmapiProvider.new(
          settings[:server], settings[:omapi_port], settings[:subnets], settings[:key_name], settings[:key_secret],
          container.get_dependency(:subnet_service), container.get_dependency(:free_ips))
      end)
    end

    def load_classes
      require 'dhcp_common/subnet_service'
      require 'dhcp_common/free_ips'
      require 'dhcp_common/isc/omapi_provider'
      require 'dhcp_common/isc/configuration_parser'
      require 'dhcp_common/isc/subnet_service_initialization'
      require 'dhcp_isc/isc_state_changes_observer'
    end
  end
end
