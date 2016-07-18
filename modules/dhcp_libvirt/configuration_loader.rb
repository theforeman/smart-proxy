module Proxy::DHCP::Libvirt
  class PluginConfiguration
    def load_dependency_injection_wirings(container, settings)
      container.dependency :memory_store, ::Proxy::MemoryStore
      container.singleton_dependency :subnet_service, (lambda do
        ::Proxy::DHCP::SubnetService.new(container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store))
      end)
      container.dependency :libvirt_network, (lambda do
        ::Proxy::DHCP::Libvirt::LibvirtDHCPNetwork.new(settings[:url], settings[:network])
      end)
      container.dependency :parser, (lambda do
        ::Proxy::DHCP::Libvirt::Parser.new(container.get_dependency(:subnet_service), container.get_dependency(:libvirt_network))
      end)
      container.dependency :dhcp_provider, (lambda do
        Proxy::DHCP::Libvirt::Provider.new(settings[:network],
                                           container.get_dependency(:libvirt_network),
                                           container.get_dependency(:subnet_service),
                                           container.get_dependency(:parser))
      end)
    end

    def load_classes
      require 'dhcp_libvirt/libvirt_dhcp_network'
      require 'dhcp_common/subnet_service'
      require 'dhcp_common/server'
      require 'dhcp_libvirt/dhcp_libvirt_main'
      require 'dhcp_libvirt/dhcp_libvirt_parser'
      require 'dhcp_common/subnet/ipv4'
      require 'dhcp_common/subnet/ipv6'
    end
  end
end
