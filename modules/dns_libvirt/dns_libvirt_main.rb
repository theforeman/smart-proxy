require 'rexml/document'

module Proxy::Dns::Libvirt
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util

    attr_reader :libvirt_network, :network

    def initialize(network, libvirt_network)
      @network = network
      @libvirt_network = libvirt_network
      super(@network)
    end

    def create_a_record(fqdn, ip)
      libvirt_network.add_dns_a_record fqdn, ip
    rescue ::Libvirt::Error => e
      logger.error msg = "Error adding DNS A record: #{e}"
      raise Proxy::Dns::Error, msg
    end
    alias :create_aaaa_record :create_a_record

    def create_ptr_record(fqdn, ip)
      # libvirt does not support PTR
    end

    def remove_a_record(fqdn)
      libvirt_network.del_dns_a_record fqdn, find_ip_for_host(fqdn)
    rescue ::Libvirt::Error => e
      logger.error msg = "Error adding DNS A record: #{e}"
      raise Proxy::Dns::Error, msg
    end
    alias :remove_aaaa_record :remove_a_record

    def remove_ptr_record(ip)
      # libvirt does not support PTR
    end

    def find_ip_for_host host
      begin
        doc = REXML::Document.new xml = libvirt_network.dump_xml
        doc.elements.each("network/dns/host/hostname") do |e|
          if e.text == host
            return e.parent.attributes["ip"]
          end
        end
      rescue Exception => e
        logger.error msg = "Unable to retrieve IP for #{host}: #{e}"
        logger.debug xml if defined?(xml)
        raise Proxy::Dns::Error, msg
      end
      raise Proxy::Dns::NotFound.new("Cannot find IP entry for #{host}")
    end
  end
end
