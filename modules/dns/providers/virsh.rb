require "proxy/virsh"
require 'rexml/document'

module Proxy::Dns
  class Virsh < Record
    include Proxy::Log
    include Proxy::Util
    include Proxy::Virsh

    def initialize options = {}
      @network = options[:virsh_network]
      raise "DNS virsh provider needs 'virsh_network' option" unless network
      super(options)
    end

    def create
      if @type == 'A'
        result = virsh_update_dns 'add-last', @fqdn, @value
        if result =~ /^Updated/
          return true
        else
          raise Proxy::Dns::Error.new("DNS update error: #{result}")
        end
      else
        logger.warn "not creating #{@type} record for #{@fqdn} (unsupported)"
      end
    end

    def remove
      if @type == 'A'
        result = virsh_update_dns 'delete', @fqdn, find_ip_for_host(@fqdn)
        if result =~ /^Updated/
          return true
        else
          raise Proxy::Dns::Error.new("DNS update error: #{result}")
        end
      else
        logger.warn "not deleting #{@type} record for #{@fqdn} (unsupported)"
      end
    end

    private

    def find_ip_for_host host
      doc = REXML::Document.new xml = dump_xml
      doc.elements.each("network/dns/host/hostname") do |e|
        if e.text == host
          return e.parent.attributes["ip"]
        end
      end
      raise Proxy::Dns::Error.new("Cannot find DNS entry for #{host}")
    rescue Exception => e
      msg = "DNS virsh provider error: unable to retrive virsh info: #{e}"
      logger.error msg
      logger.debug xml if defined?(xml)
      raise Proxy::Dns::Error, msg
    end

    def virsh_update_dns command, hostname, ip
      hostname = escape_for_shell(hostname)
      ip = escape_for_shell(ip)
      net = escape_for_shell(network)
      virsh "net-update", net, command, "dns-host",
            "--xml", "'<host ip=\"#{ip}\"><hostname>#{hostname}</hostname></host>'",
            "--live", "--config"
    rescue Proxy::Virsh::Error => e
      raise Proxy::Dns::Error, "Failed to update DNS: #{e}"
    end

  end
end
