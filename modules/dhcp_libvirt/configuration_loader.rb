module Proxy::DHCP::Libvirt
  class PluginConfiguration
    def load_dependency_injection_wirings(container, settings)
      container.dependency :memory_store, ::Proxy::MemoryStore
      container.dependency :subnet_service, (lambda do
        ::Proxy::DHCP::SubnetService.new(container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store))
      end)
      container.dependency :libvirt_network, (lambda do
        ::Proxy::DHCP::Libvirt::LibvirtDHCPNetwork.new(settings[:url], settings[:network])
      end)
      container.dependency :initialized_subnet_service, (lambda do
        ::Proxy::DHCP::Libvirt::SubnetServiceInitializer.new(container.get_dependency(:libvirt_network)).initialized_subnet_service(container.get_dependency(:subnet_service))
      end)
      container.singleton_dependency :free_ips, lambda {::Proxy::DHCP::FreeIps.new }
      container.dependency :dhcp_provider, (lambda do
        Proxy::DHCP::Libvirt::Provider.new(settings[:network], container.get_dependency(:libvirt_network),
                                           container.get_dependency(:initialized_subnet_service),
                                           container.get_dependency(:free_ips))
      end)
    end

    def load_classes
      require 'dhcp_libvirt/libvirt_dhcp_network'
      require 'dhcp_common/subnet_service'
      require 'dhcp_common/server'
      require 'dhcp_common/free_ips'
      require 'dhcp_libvirt/subnet_service_initializer'
      require 'dhcp_libvirt/dhcp_libvirt_main'
    end
  end
end
