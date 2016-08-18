module Proxy::DHCP::Libvirt
  class Provider < ::Proxy::DHCP::Server
    attr_reader :network, :parser
    attr_accessor :libvirt_network

    def initialize(network, libvirt_network_impl, subnet_service, parser)
      @network = network
      @libvirt_network = libvirt_network_impl
      @parser = parser
      super(@network, nil, subnet_service)
    end

    def load_subnets
      super
      parser.load_subnets
    end

    def load_subnet_data(subnet)
      super(subnet)
      parser.load_subnet_data(subnet)
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
