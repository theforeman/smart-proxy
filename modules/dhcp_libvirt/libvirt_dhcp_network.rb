require 'libvirt'
require 'libvirt_common/libvirt_network'

module ::Proxy::DHCP::Libvirt
  class LibvirtDHCPNetwork < Proxy::LibvirtNetwork
    attr_accessor :index_v4, :index_v6

    def dhcp_leases
      find_network.dhcp_leases
    rescue ArgumentError
      # workaround for ruby-libvirt < 0.6.1 - DHCP leases API is broken there
      # (http://libvirt.org/git/?p=ruby-libvirt.git;a=commit;h=c2d4192ebf28b8030b753b715a72f0cdf725d313)
      []
    end

    def add_dhcp_record(record)
      xml = change_xml record
      network_update ::Libvirt::Network::UPDATE_COMMAND_ADD_LAST, ::Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST, xml, index(record)
    end

    def del_dhcp_record(record)
      xml = change_xml record
      network_update ::Libvirt::Network::UPDATE_COMMAND_DELETE, ::Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST, xml, index(record)
    end

    private

    def index(record)
      record.v6? ? index_v6 : index_v4
    end

    def change_xml(record)
      nametag = "name=\"#{record.name}\"" if record.name
      change_record(record, nametag)
    end

    def change_record(record, nametag)
      if record.v6?
        change_dhcpv6_record record, nametag
      else
        change_dhcpv4_record record, nametag
      end
    end

    def change_dhcpv6_record(record, nametag)
      idtag = "id=\"#{record.id}\"" if record.id
      "<host #{idtag} ip=\"#{record.ip}\" #{nametag}/>"
    end

    def change_dhcpv4_record(record, nametag)
     "<host mac=\"#{record.mac}\" ip=\"#{record.ip}\" #{nametag}/>"
    end
  end
end
