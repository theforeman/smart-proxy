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
        ::Proxy::DHCP::SubnetService.new(container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store))
      end)

      load_wirings_for_files container, settings

      container.dependency :dhcp_provider, (lambda do
        Proxy::DHCP::ISC::Provider.new(
            settings[:server], settings[:omapi_port], settings[:subnets], settings[:key_name], settings[:key_secret],
            container.get_dependency(:subnet_service))
      end)
    end

    def load_classes
      require 'dhcp_common/subnet_service'
      require 'dhcp_common/server'
      require 'dhcp_isc/isc_file_parser4'
      require 'dhcp_isc/isc_file_parser6'
      require 'dhcp_isc/configuration_file'
      require 'dhcp_isc/leases_file'
      require 'dhcp_isc/isc_state_changes_observer'
      require 'dhcp_isc/dhcp_isc_main'
      require 'dhcp_common/subnet/ipv4'
      require 'dhcp_common/subnet/ipv6'
    end

    private

    def versions
      %w(4 6)
    end

    def dep_name(name, ver)
      "#{name}#{ver}".to_sym
    end

    def load_wirings_for_files(container, settings)
      versions.each do |ver|
        parser_class = Kernel.const_get "::Proxy::DHCP::ISC::FileParser#{ver}"
        container.dependency dep_name(:parser, ver), lambda { parser_class.new(container.get_dependency(:subnet_service)) }
        container.dependency dep_name(:config_file, ver), lambda {
          ::Proxy::DHCP::ISC::ConfigurationFile.new(settings[dep_name(:config, ver)], container.get_dependency(dep_name(:parser, ver))) }
        container.dependency dep_name(:leases_file, ver), lambda {
          ::Proxy::DHCP::ISC::LeasesFile.new(settings[dep_name(:leases, ver)], container.get_dependency(dep_name(:parser, ver))) }
        container.dependency dep_name(:state_changes_observer, ver), (lambda do
          ::Proxy::DHCP::ISC::IscStateChangesObserver.new(container.get_dependency(dep_name(:config_file, ver)),
                                                          container.get_dependency(dep_name(:leases_file, ver)),
                                                          container.get_dependency(:subnet_service))
        end)
        load_wirings_for_observers container, settings, ver
      end
    end

    def load_wirings_for_observers(container, settings, ipv)
      if settings[:leases_file_observer] == :inotify_leases_file_observer
        require 'dhcp_isc/inotify_leases_file_observer'
        container.singleton_dependency dep_name(:leases_observer, ipv), (lambda do
          ::Proxy::DHCP::ISC::InotifyLeasesFileObserver.new(container.get_dependency(dep_name(:state_changes_observer, ipv)), settings[dep_name(:leases, ipv)])
        end)
      elsif settings[:leases_file_observer] == :kqueue_leases_file_observer
        require 'dhcp_isc/kqueue_leases_file_observer'
        container.singleton_dependency dep_name(:leases_observer, ipv), (lambda do
          ::Proxy::DHCP::ISC::KqueueLeasesFileObserver.new(container.get_dependency(dep_name(:state_changes_observer, ipv)), settings[dep_name(:leases, ipv)])
        end)
      end
    end
  end
end
