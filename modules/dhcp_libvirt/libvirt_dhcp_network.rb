require 'libvirt'
require 'libvirt_common/libvirt_network'

module ::Proxy::DHCP::Libvirt
  class LibvirtDHCPNetwork < Proxy::LibvirtNetwork
    def dhcp_leases
      find_network.dhcp_leases
    rescue ArgumentError
      # workaround for ruby-libvirt < 0.6.1 - DHCP leases API is broken there
      # (http://libvirt.org/git/?p=ruby-libvirt.git;a=commit;h=c2d4192ebf28b8030b753b715a72f0cdf725d313)
      []
    end

    def add_dhcp_record(record)
      nametag = "name=\"#{record.name}\"" if record.name
      xml = "<host mac=\"#{record.mac}\" ip=\"#{record.ip}\" #{nametag}/>"
      network_update ::Libvirt::Network::UPDATE_COMMAND_ADD_LAST, ::Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST, xml
    end

    def del_dhcp_record(record)
      nametag = "name=\"#{record.name}\"" if record.name
      xml = "<host mac=\"#{record.mac}\" ip=\"#{record.ip}\" #{nametag}/>"
      network_update ::Libvirt::Network::UPDATE_COMMAND_DELETE, ::Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST, xml
    end

    def leased_ip?(ip)
      !dhcp_leases.select { |lease| lease['ip'] == ip }.empty?
    end
  end
end
