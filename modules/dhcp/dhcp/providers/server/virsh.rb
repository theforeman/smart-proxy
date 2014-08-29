require 'proxy/virsh'
require 'rexml/document'
require 'ipaddr'

module Proxy::DHCP
  class Virsh < Server
    include Proxy::Virsh

    def initialize options
      @network = options[:virsh_network]
      raise "DNS virsh provider needs 'virsh_network' option" unless network
      super(options)
    end

    # we support only one subnet
    def loadSubnets
      super
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
          subnet = Proxy::DHCP::Subnet.new(self, network, netmask)
        end
      rescue Exception => e
        msg = "DHCP virsh provider error: unable to retrive virsh info: #{e}"
        logger.error msg
        logger.debug xml if defined?(xml)
        raise Proxy::DHCP::Error, msg
      end
    end

    def loadSubnetData subnet
      super(subnet)
      begin
        doc = REXML::Document.new xml = dump_xml
        REXML::XPath.each(doc, "//network/ip[not(@family) or @family='ipv4']/dhcp/host") do |e|
          Proxy::DHCP::Reservation.new(:subnet => subnet,
                                  :ip => e.attributes["ip"],
                                  :mac => e.attributes["mac"],
                                  :hostname => e.attributes["name"])
        end
      rescue Exception => e
        msg = "DHCP virsh provider error: unable to retrive virsh info: #{e}"
        logger.error msg
        logger.debug xml if defined?(xml)
        raise Proxy::DHCP::Error, msg
      end
    end

    def addRecord options={}
      record = super(options)
      virsh_update_dhcp 'add-last', record.mac, record.ip, record.name
      record
    end

    def delRecord subnet, record
      super(subnet, record)
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

      virsh "net-update", net, command, "ip-dhcp-host",
        "--xml", xml, "--live", "--config"
    rescue Proxy::Virsh::Error => e
      raise Proxy::DHCP::Error, "Failed to update DHCP: #{e}"
    end

  end
end
