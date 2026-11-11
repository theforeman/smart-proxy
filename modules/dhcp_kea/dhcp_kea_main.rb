require 'ipaddr'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/server'

module Proxy::DHCP::Kea
  class Provider < ::Proxy::DHCP::Server
    # Kea lease states, see the lease_cmds hook documentation
    LEASE_STATES = {0 => 'active', 1 => 'declined', 2 => 'expired-reclaimed', 3 => 'released'}.freeze

    SUBNET_OPTIONS = {
      'routers' => :routers,
      'domain-name-servers' => :domain_name_servers,
      'domain-name' => :domain_name,
      'ntp-servers' => :ntp_servers,
      'interface-mtu' => :interface_mtu,
    }.freeze

    attr_reader :kea_client

    def initialize(kea_client, managed_subnets = nil, free_ips_service = nil)
      super('kea', managed_subnets, nil, free_ips_service)
      @kea_client = kea_client
    end

    def validate_supported_address(*args)
      args.each { |ip| validate_ip(ip, 4) }
    end

    def subnets
      kea_subnets.values.map { |s| s[:subnet] }
    end

    def find_subnet(subnet_address)
      kea_subnets[subnet_address]&.fetch(:subnet)
    end

    def get_subnet(subnet_address)
      find_subnet(subnet_address) || raise(Proxy::DHCP::SubnetNotFound, "No such subnet: #{subnet_address}")
    end

    def all_hosts(subnet_address)
      subnet = get_subnet(subnet_address)
      kea_client.reservations(subnet_id(subnet)).map { |host| build_reservation(host, subnet) }.compact
    end

    def all_leases(subnet_address)
      subnet = get_subnet(subnet_address)
      kea_client.leases(subnet_id(subnet)).map { |lease| build_lease(lease, subnet) }.compact
    end

    def find_records_by_ip(subnet_address, ip)
      subnet = get_subnet(subnet_address)
      host = kea_client.reservation_by_ip(subnet_id(subnet), ip)
      return [build_reservation(host, subnet)].compact if host
      lease = kea_client.lease_by_ip(ip)
      return [build_lease(lease, subnet)].compact if lease && lease['subnet-id'] == subnet_id(subnet)
      []
    end

    def find_record_by_mac(subnet_address, mac_address)
      subnet = get_subnet(subnet_address)
      host = kea_client.reservation_by_mac(subnet_id(subnet), mac_address)
      return build_reservation(host, subnet) if host
      lease = kea_client.lease_by_mac(subnet_id(subnet), mac_address)
      build_lease(lease, subnet) if lease
    end

    def find_ip_by_mac_address_and_range(subnet, mac_address, from_address, to_address)
      record = find_record_by_mac(subnet.network, mac_address)
      if record && (IPAddr.new(from_address)..IPAddr.new(to_address)).cover?(IPAddr.new(record.ip))
        logger.debug "Found an existing DHCP record #{record}, reusing..."
        return record.ip
      end
      nil
    end

    def find_similar_records(subnet_address, ip_address, mac_address)
      subnet = get_subnet(subnet_address)
      [
        kea_client.reservation_by_ip(subnet_id(subnet), ip_address),
        kea_client.reservation_by_mac(subnet_id(subnet), mac_address),
      ].compact.uniq.map { |host| build_reservation(host, subnet) }.compact
    end

    def add_record(options = {})
      record = super(options)

      reservation = {
        'subnet-id' => subnet_id(record.subnet),
        'ip-address' => record.ip,
        'hw-address' => record.mac,
        'hostname' => record.hostname || record.name,
      }
      reservation['next-server'] = next_server_address(record.nextServer) if record.nextServer
      reservation['boot-file-name'] = record.filename if record.filename

      begin
        kea_client.add_reservation(reservation)
      rescue Proxy::DHCP::Error => e
        raise Proxy::DHCP::Collision, "Record #{record.subnet.network}/#{record.ip} already exists" if e.message.include?('duplicate')
        raise
      end

      logger.info "Created Kea reservation #{record}"
      record
    end

    def del_record(record)
      logger.debug "Deleting '#{record}'"
      if record.is_a?(::Proxy::DHCP::Reservation)
        kea_client.delete_reservation(subnet_id(record.subnet), record.mac)
      else
        kea_client.delete_lease(record.ip)
      end
    end

    private

    def kea_subnets
      @kea_subnets ||= kea_client.subnets.each_with_object({}) do |config, all|
        network, prefix = config['subnet'].split('/')
        # IPAddr#netmask requires Ruby 3.1
        netmask = IPAddr.new('255.255.255.255').mask(prefix.to_i).to_s
        next unless managed_subnet?("#{network}/#{netmask}")
        subnet = ::Proxy::DHCP::Subnet.new(network, netmask, subnet_options(config))
        all[network] = {:subnet => subnet, :id => config['id']}
      rescue Proxy::Validations::Error, Proxy::DHCP::Error, IPAddr::Error => e
        logger.warn "Skipping Kea subnet #{config['subnet']}: #{e.message}"
      end
    end

    def subnet_id(subnet)
      kea_subnets.fetch(subnet.network)[:id]
    end

    def subnet_options(config)
      options = (config['option-data'] || []).each_with_object({}) do |option, all|
        name = SUBNET_OPTIONS[option['name']]
        all[name] = option['data'].split(',').map(&:strip) if name && option['data']
      end
      options[:domain_name] = options[:domain_name].first if options[:domain_name]
      pool = (config['pools'] || []).first
      options[:range] = pool_range(pool['pool']) if pool
      options
    end

    def pool_range(pool)
      return pool.split('-').map(&:strip) if pool.include?('-')
      range = IPAddr.new(pool).to_range
      [range.first.to_s, range.last.to_s]
    end

    def build_reservation(host, subnet)
      options = {:hostname => host['hostname']}
      options[:nextServer] = host['next-server'] unless host['next-server'].to_s.empty? || host['next-server'] == '0.0.0.0'
      options[:filename] = host['boot-file-name'] unless host['boot-file-name'].to_s.empty?
      ::Proxy::DHCP::Reservation.new(host['hostname'], host['ip-address'], host['hw-address'], subnet, options)
    rescue Proxy::Validations::Error => e
      logger.debug "Skipping invalid Kea reservation #{host.inspect}: #{e.message}"
      nil
    end

    def build_lease(lease, subnet)
      return nil if lease['state'] == 2 # expired-reclaimed, the address is free
      starts = Time.at(lease['cltt']).utc
      ends = Time.at(lease['cltt'] + lease['valid-lft']).utc
      name = lease['hostname'].to_s.empty? ? nil : lease['hostname']
      ::Proxy::DHCP::Lease.new(name, lease['ip-address'], lease['hw-address'], subnet, starts, ends, LEASE_STATES[lease['state']])
    rescue Proxy::Validations::Error => e
      logger.debug "Skipping invalid Kea lease #{lease.inspect}: #{e.message}"
      nil
    end

    def next_server_address(server)
      validate_ip(server, 4)
    rescue Proxy::Validations::Error
      logger.info "Next-server '#{server}' is not an IPv4 address, resolving it"
      begin
        dns_resolv.getresource(server, Resolv::DNS::Resource::IN::A).address.to_s
      rescue Resolv::ResolvError => e
        raise Proxy::DHCP::Error, "Unable to resolve next-server '#{server}' to an IPv4 address: #{e.message}"
      end
    end
  end
end
