require 'proxy/virsh'
require 'rexml/document'
require 'ipaddr'
require 'dhcp_common/server'

module Proxy::DHCP::Virsh
  class Provider < ::Proxy::DHCP::Server
    include Proxy::Virsh

    attr_reader :name, :network, :leases

    def initialize
      super("127.0.0.1")
      @network = Proxy::DHCP::Virsh::Plugin.settings.network
      @leases = Proxy::DHCP::Virsh::Plugin.settings.leases
    end

    def initialize_for_testing(params)
      @name = params[:name] || @name
      @service = params[:service] || service
      @network = params[:network] || @network
      self
    end

    # we support only one subnet
    def load_subnets
      super
      service.add_subnets(*parse_config_for_subnets)
    end

    def parse_config_for_subnets
      ret_val = []
      begin
        doc = REXML::Document.new xml = dump_xml
        doc.elements.each("network/ip") do |e|
          next if e.attributes["family"] == "ipv6"
          gateway = e.attributes["address"]

          if e.attributes["netmask"].nil? then
            # converts a prefix/cidr notation to octets
            netmask = IPAddr.new(gateway).mask(e.attributes["prefix"]).to_mask
          else
            netmask = e.attributes["netmask"]
          end

          network = IPAddr.new(gateway).mask(netmask).to_s
          ret_val << Proxy::DHCP::Subnet.new(network, netmask)
        end
      rescue Exception => e
        msg = "DHCP virsh provider error: unable to retrive virsh info: #{e}"
        logger.error msg
        logger.debug xml if defined?(xml)
        raise Proxy::DHCP::Error, msg
      end

      ret_val
    end

    def parse_config_for_dhcp_reservations(subnet)
    to_ret = []
      doc = REXML::Document.new xml = dump_xml
      REXML::XPath.each(doc, "//network/ip[not(@family) or @family='ipv4']/dhcp/host") do |e|
        to_ret << Proxy::DHCP::Reservation.new(:subnet => subnet, :ip => e.attributes["ip"],
                                               :mac => e.attributes["mac"], :hostname => e.attributes["name"])
      end
      to_ret
    rescue Exception => e
      msg = "DHCP virsh provider error: unable to retrive virsh info: #{e}"
      logger.error msg
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    def parse_json_for_dhcp_leases
      JSON.parse(File.read(@leases))
    rescue Exception => e
      msg = "DHCP virsh provider error: unable to retrive leases from #{@leases}: #{e}"
      logger.error msg
      logger.debug xml if defined?(xml)
      raise Proxy::DHCP::Error, msg
    end

    def load_subnet_data subnet
      super(subnet)
      reservations = parse_config_for_dhcp_reservations(subnet)
      reservations.each { |record| service.add_host(record.subnet_address, record) }
      leases = parse_json_for_dhcp_leases
      leases.each do |element|
        lease = Proxy::DHCP::Lease.new(
          :subnet => subnet,
          :ip => element['ip-address'],
          :mac => element['mac-address'],
          :starts => Time.now.utc,
          :ends => Time.at(element['expiry-time']).utc,
          :state => 'active'
        )
        service.add_lease(lease.subnet_address, lease)
      end
    end

    def add_record options={}
      record = super(options)
      virsh_update_dhcp 'add-last', record.mac, record.ip, record.name
      record
    end

    def del_record subnet, record
      virsh_update_dhcp 'delete', record.mac, record.ip, record[:hostname]
    end

    def virsh_update_dhcp command, mac, ip, name
      mac = escape_for_shell(mac)
      ip = escape_for_shell(ip)
      net = escape_for_shell(network)

      if name
        name = escape_for_shell(name)
        xml = "'<host mac=\"#{mac}\" name=\"#{name}\" ip=\"#{ip}\"/>'"
      else
        xml = "'<host mac=\"#{mac}\" ip=\"#{ip}\"/>'"
      end

      virsh "net-update", net, command, "ip-dhcp-host", "--xml", xml, "--live", "--config"
    rescue Proxy::Virsh::Error => e
      raise Proxy::DHCP::Error, "Failed to update DHCP: #{e}"
    end
  end
end
