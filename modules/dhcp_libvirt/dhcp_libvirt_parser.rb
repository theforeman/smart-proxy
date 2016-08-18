require 'rexml/document'
require 'ipaddr'

module Proxy::DHCP::Libvirt
  class Parser
    include Proxy::Log

    attr_reader :service
    attr_accessor :libvirt_network

    def initialize(subnet_service, libvirt_network)
      @service = subnet_service
      @libvirt_network = libvirt_network
    end

    def load_subnets
      service.add_subnets(*parse_config_for_subnets)
    end

    def parse_config_for_subnets
      ret_val = []
      doc = REXML::Document.new xml = libvirt_network.dump_xml
      doc.elements.each_with_index("network/ip") do |elem, index|
        if elem.attributes["family"] == "ipv6"
          ret_val << parse_ipv6_subnet(elem)
          libvirt_network.index_v6 = index
        else
          ret_val << parse_ipv4_subnet(elem)
          libvirt_network.index_v4 = index
        end
      end
      raise Proxy::DHCP::Error("Only one subnet is supported") if ret_val.partition { |net| net.v6? }.any? { |ary| ary.count > 1 }
      ret_val
    rescue Exception => e
      logger.error msg = "Unable to parse subnets XML: #{e}"
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    def parse_ipv4_subnet(elem)
      gateway = elem.attributes["address"]
      if elem.attributes["netmask"].nil? then
        # converts a prefix/cidr notation to octets
        netmask = IPAddr.new(gateway).mask(elem.attributes["prefix"]).to_mask
      else
        netmask = elem.attributes["netmask"]
      end
      Proxy::DHCP::Ipv4.new(gateway, netmask)
    end

    def parse_ipv6_subnet(elem)
      gateway = elem.attributes["address"]
      prefix = elem.attributes["prefix"]
      Proxy::DHCP::Ipv6.new(gateway, prefix)
    end

    def parse_config_for_dhcp_reservations(subnet)
      doc = REXML::Document.new xml = libvirt_network.dump_xml
      if subnet.v6?
        parse_v6_reservations(doc, subnet)
      else
        parse_v4_reservations(doc, subnet)
      end
    rescue Exception => e
      logger.error msg = "Unable to parse reservations XML: #{e}"
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    def parse_v4_reservations(doc, subnet)
      to_ret = []
      REXML::XPath.each(doc, "//network/ip[not(@family) or @family='ipv4']/dhcp/host") do |e|
        to_ret << Proxy::DHCP::Reservation.new(
          :subnet => subnet,
          :ip => e.attributes["ip"],
          :mac => e.attributes["mac"],
          :hostname => e.attributes["name"])
      end
      to_ret
    end

    def parse_v6_reservations(doc, subnet)
      to_ret = []
      REXML::XPath.each(doc, "//network/ip[@family='ipv6']/dhcp/host") do |e|
        to_ret << Proxy::DHCP::Reservation.new(
          :subnet => subnet,
          :ip => e.attributes["ip"],
          :id => e.attributes["id"],
          :hostname => e.attributes["name"])
      end
      to_ret
    end

    def load_subnet_data(subnet)
      reservations = parse_config_for_dhcp_reservations(subnet)
      reservations.each { |record| service.add_host(record.subnet_address, record) }
      leases = libvirt_network.dhcp_leases
      leases.each do |element|
        lease = Proxy::DHCP::Lease.new(
          :subnet => subnet,
          :ip => element['ipaddr'],
          :mac => element['mac'],
          :starts => Time.now.utc,
          :ends => Time.at(element['expirytime'] || 0).utc,
          :state => 'active'
        )
        service.add_lease(lease.subnet_address, lease)
      end
    end
  end
end