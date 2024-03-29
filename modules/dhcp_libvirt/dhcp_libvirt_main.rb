module Proxy::DHCP::Libvirt
  class Provider < ::Proxy::DHCP::Server
    attr_reader :libvirt_network, :network

    def initialize(network, libvirt_network_impl, subnet_service, free_ips_service)
      @network = network
      @libvirt_network = libvirt_network_impl
      super(@network, nil, subnet_service, free_ips_service)
    end

    def validate_supported_address(*args)
      args.each do |ip|
        validate_ip(ip, 4)
      end
    end

    def add_record(options = {})
      record = super(options)
      libvirt_network.add_dhcp_record record
      record
    rescue ::Libvirt::Error => e
      msg = "Error adding DHCP record"
      logger.error msg, e
      raise Proxy::DHCP::Error, msg
    end

    def del_record(record)
      # libvirt only supports one subnet per network
      libvirt_network.del_dhcp_record record
    rescue ::Libvirt::Error => e
      msg = "Error removing DHCP record"
      logger.error msg, e
      raise Proxy::DHCP::Error, msg
    end
  end
end
