require 'dhcp_libvirt/libvirt_dhcp_network'
require 'rexml/document'
require 'ipaddr'
require 'dhcp_common/server'

module Proxy::DHCP::Libvirt
  class Provider < ::Proxy::DHCP::Server
    attr_reader :libvirt_network, :network

    def initialize(options = {})
      @network = options[:network] || Proxy::DHCP::Libvirt::Plugin.settings.network
      @libvirt_network = options[:libvirt_network] || ::Proxy::DHCP::Libvirt::LibvirtDHCPNetwork.new(
        options[:url] || Proxy::DHCP::Libvirt::Plugin.settings.url,
        @network)
      super(@network)
    end

    def initialize_for_testing(params)
      @service = params[:service] || service
      self
    end

    def load_subnets
      super
      service.add_subnets(*parse_config_for_subnets)
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
      logger.error msg = "Unable to parse subnets XML: #{e}"
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    def parse_config_for_dhcp_reservations(subnet)
      to_ret = []
      doc = REXML::Document.new xml = libvirt_network.dump_xml
      REXML::XPath.each(doc, "//network/ip[not(@family) or @family='ipv4']/dhcp/host") do |e|
        to_ret << Proxy::DHCP::Reservation.new(
          :subnet => subnet,
          :ip => e.attributes["ip"],
          :mac => e.attributes["mac"],
          :hostname => e.attributes["name"])
      end
      to_ret
    rescue Exception => e
      logger.error msg = "Unable to parse reservations XML: #{e}"
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    def load_subnet_data(subnet)
      super(subnet)
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

    def add_record(options={})
      record = super(options)
      libvirt_network.add_dhcp_record record
      record
    rescue ::Libvirt::Error => e
      logger.error msg = "Error adding DHCP record: #{e}"
      raise Proxy::DHCP::Error, msg
    end

    def del_record(_, record)
      # libvirt only supports one subnet per network
      libvirt_network.del_dhcp_record record
    rescue ::Libvirt::Error => e
      logger.error msg = "Error removing DHCP record: #{e}"
      raise Proxy::DHCP::Error, msg
    end
  end
end
