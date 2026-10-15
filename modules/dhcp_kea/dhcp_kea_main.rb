require 'dhcp_common/server'

module Proxy::DHCP::Kea
  class Provider < ::Proxy::DHCP::Server
    include Proxy::Log

    attr_reader :kea_client, :lease_timeout

    def initialize(kea_client, subnet_service, free_ips_service, lease_timeout = 60)
      @kea_client = kea_client
      @lease_timeout = lease_timeout

      super('kea-dhcp-server', nil, subnet_service, free_ips_service)

      load_subnets
    end

    def load_subnets
      logger.info "Loading subnets from KEA DHCP server"

      begin
        subnets = kea_client.list_subnets
      rescue => e
        logger.error "Failed to load subnets from KEA: #{e.message}"
        raise Proxy::DHCP::Error, "Cannot connect to KEA DHCP server: #{e.message}"
      end

      if subnets.empty?
        logger.warn "No subnets configured in KEA DHCP server"
        return
      end

      subnets.each do |subnet_config|
        network_cidr = subnet_config['subnet']
        subnet_id = subnet_config['id']

        logger.debug "Loading subnet: #{network_cidr} (KEA ID: #{subnet_id})"

        # Extract network address and netmask from CIDR (e.g., "192.168.1.0/24" -> "192.168.1.0", "255.255.255.0")
        network = network_cidr.split('/').first
        netmask = netmask_from_cidr(network_cidr)

        subnet = ::Proxy::DHCP::Subnet.new(network, netmask)

        subnet.options[:kea_subnet_id] = subnet_id

        service.add_subnet(subnet)

        logger.debug "Added subnet #{network_cidr} with KEA ID #{subnet_id}"
      end

      logger.info "Loaded #{subnets.size} subnet(s) from KEA"
    end

    def add_record(options = {})
      logger.debug "Adding DHCP reservation with options: #{options.inspect}"

      record = super(options)

      # The parent class already validated and set record.subnet
      subnet = record.subnet

      subnet_id = subnet.options[:kea_subnet_id]
      unless subnet_id
        raise Proxy::DHCP::Error, "KEA subnet ID not found for #{subnet.network}"
      end

      kea_options = {}
      kea_options[:next_server] = record.nextServer if record.nextServer
      kea_options[:boot_file_name] = record.filename if record.filename

      begin
        kea_client.add_reservation(
          subnet_id,
          record.ip,
          record.mac,
          record.name,
          kea_options
        )
      rescue => e
        logger.error "Failed to create KEA reservation: #{e.message}"
        raise Proxy::DHCP::Error, "Failed to create reservation in KEA: #{e.message}"
      end

      service.add_host(subnet.network, record)

      logger.info "Successfully created KEA DHCP reservation: #{record.ip} for #{record.mac}"
      record
    end

    def del_record(record)
      logger.debug "Deleting DHCP record: #{record.inspect}"

      # Record already has the subnet object
      subnet = record.subnet

      subnet_id = subnet.options[:kea_subnet_id]
      unless subnet_id
        raise Proxy::DHCP::Error, "KEA subnet ID not found for #{subnet.network}"
      end

      begin
        kea_client.delete_reservation_by_ip(subnet_id, record.ip)
      rescue => e
        logger.error "Failed to delete KEA reservation: #{e.message}"
        raise Proxy::DHCP::Error, "Failed to delete reservation from KEA: #{e.message}"
      end

      if record.is_a?(::Proxy::DHCP::Reservation)
        service.delete_host(record)
      elsif record.is_a?(::Proxy::DHCP::Lease)
        service.delete_lease(subnet.network, record)
      end

      logger.info "Successfully deleted KEA DHCP reservation: #{record.ip}"
    end

    def load_subnet_options(subnet)
      logger.debug "Loading subnet options for #{subnet.network}"
    end

    private

    def netmask_from_cidr(cidr)
      prefix = cidr.split('/').last.to_i

      mask = (0xffffffff << (32 - prefix)) & 0xffffffff
      [mask].pack('N').unpack('C4').join('.')
    end
  end
end
