require "proxy/virsh"
require 'rexml/document'
require 'dns_common/dns_common'

module Proxy::Dns::Virsh
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util
    include Proxy::Virsh

    def initialize(a_network = nil)
      @network = a_network || ::Proxy::SETTINGS.virsh_network
      raise "DNS virsh provider needs 'virsh_network' option" unless @network
      super(nil, nil)
    end

    def create_a_record(fqdn, ip)
      result = virsh_update_dns 'add-last', fqdn, ip
      if result =~ /^Updated/
        return true
      else
        raise Proxy::Dns::Error.new("DNS update error: #{result}")
      end
    end

    def create_ptr_record(fqdn, ip)
      logger.warn "not creating PTR record for #{fqdn} (unsupported)"
    end

    def remove_a_record(fqdn)
      result = virsh_update_dns 'delete', fqdn, find_ip_for_host(fqdn)
      if result =~ /^Updated/
        return true
      else
        raise Proxy::Dns::Error.new("DNS update error: #{result}")
      end
    end

    def remove_ptr_record(ip)
      logger.warn "not deleting PTR record for #{ip} (unsupported)"
    end

    def find_ip_for_host host
      begin
        doc = REXML::Document.new xml = dump_xml
        doc.elements.each("network/dns/host/hostname") do |e|
          if e.text == host
            return e.parent.attributes["ip"]
          end
        end
      rescue Exception => e
        msg = "DNS virsh provider error: unable to retrieve virsh info: #{e}"
        logger.error msg
        logger.debug xml if defined?(xml)
        raise Proxy::Dns::Error, msg
      end
      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{host}")
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
