require 'libvirt'
require 'libvirt_common/libvirt_network'

module ::Proxy::Dns::Libvirt
  class LibvirtDNSNetwork < Proxy::LibvirtNetwork
    def add_dns_a_record(fqdn, ip)
      xml = "<host ip=\"#{ip}\"><hostname>#{fqdn}</hostname></host>"
      network_update ::Libvirt::Network::UPDATE_COMMAND_ADD_LAST, ::Libvirt::Network::NETWORK_SECTION_DNS_HOST, xml
    end

    def del_dns_a_record(fqdn, ip)
      xml = "<host ip=\"#{ip}\"><hostname>#{fqdn}</hostname></host>"
      network_update ::Libvirt::Network::UPDATE_COMMAND_DELETE, ::Libvirt::Network::NETWORK_SECTION_DNS_HOST, xml
    end
  end
end
