module ::Proxy::Dns::Libvirt
  class PluginConfiguration
    def load_classes
      require 'dns_common/dns_common'
      require 'dns_libvirt/libvirt_dns_network'
      require 'dns_libvirt/dns_libvirt_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :libvirt_network, lambda {::Proxy::Dns::Libvirt::LibvirtDNSNetwork.new(settings[:url], settings[:network]) }
      container_instance.dependency :dns_provider, lambda {::Proxy::Dns::Libvirt::Record.new(settings[:network], container_instance.get_dependency(:libvirt_network)) }
    end
  end
end
