require 'rexml/document'
require 'ipaddr'

module Proxy::DHCP::Libvirt
  class SubnetServiceInitializer
    include Proxy::Log

    attr_reader :libvirt_network

    def initialize(libvirt_network)
      @libvirt_network = libvirt_network
    end

    def initialized_subnet_service(subnet_service)
      subnet_service.add_subnets(*parse_config_for_subnets)
      load_subnet_data(subnet_service)
      subnet_service
    end

    def parse_config_for_subnets
      ret_val = []
      doc = REXML::Document.new xml = libvirt_network.dump_xml
      doc.elements.each("network/ip") do |e|
        next if e.attributes["family"] == "ipv6"
        gateway = e.attributes["address"]

        if e.attributes["netmask"].nil? then
          # converts a prefix/cidr notation to octets
          netmask = IPAddr.new(gateway).mask(e.attributes["prefix"]).to_mask
        else
          netmask = e.attributes["netmask"]
        end

        a_network = IPAddr.new(gateway).mask(netmask).to_s
        ret_val << Proxy::DHCP::Subnet.new(a_network, netmask)
      end
      raise Proxy::DHCP::Error("Only one subnet is supported") if ret_val.size > 1
      ret_val
    rescue Exception => e
      msg = "Unable to parse subnets XML"
      logger.error msg, e
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    # Expects subnet_service to have subnet data
    def parse_config_for_dhcp_reservations(subnet_service)
      to_ret = []
      doc = REXML::Document.new xml = libvirt_network.dump_xml
      REXML::XPath.each(doc, "//network/ip[not(@family) or @family='ipv4']/dhcp/host") do |e|
        subnet = subnet_service.find_subnet(e.attributes['ip'])
        to_ret << Proxy::DHCP::Reservation.new(
          e.attributes["name"],
          e.attributes["ip"],
          e.attributes["mac"],
          subnet,
          :hostname => e.attributes["name"])
      end
      to_ret
    rescue Exception => e
      msg = "Unable to parse reservations XML"
      logger.error msg, e
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    def load_subnet_data(subnet_service)
      reservations = parse_config_for_dhcp_reservations(subnet_service)
      reservations.each { |record| subnet_service.add_host(record.subnet_address, record) }
      leases = load_leases(subnet_service)
      leases.each { |lease| subnet_service.add_lease(lease.subnet_address, lease) }
    end

    # Expects subnet_service to have subnet data
    def load_leases(subnet_service)
      leases = libvirt_network.dhcp_leases
      leases.map do |element|
        subnet = subnet_service.find_subnet(element['ipaddr'])
        Proxy::DHCP::Lease.new(
          nil,
          element['ipaddr'],
          element['mac'],
          subnet,
          Time.now.utc,
          Time.at(element['expirytime'] || 0).utc,
          'active'
        )
      end
    end
  end
end
