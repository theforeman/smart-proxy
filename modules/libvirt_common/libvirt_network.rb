require 'libvirt'

module Proxy
  class LibvirtNetwork
    include Proxy::Log
    include Proxy::Util

    attr_reader :url, :network

    def initialize(url = nil, network = nil)
      @network = network
      @url = url
    end

    def connection
      @connection ||= ::Libvirt::open(@url)
    end

    def dump_xml
      find_network.xml_desc
    end

    def find_network
      connection.lookup_network_by_name(@network)
    end

    def network_update(command, section, xml, index = -1)
      flags = ::Libvirt::Network::NETWORK_UPDATE_AFFECT_LIVE | ::Libvirt::Network::NETWORK_UPDATE_AFFECT_CONFIG
      logger.debug "Libvirt update: #{xml}"
      find_network.update command, section, index, xml, flags
    rescue ::Libvirt::Error => e
      logger.error "Error calling libvirt update: #{e}"
      logger.debug xml
      raise e
    end
  end
end
