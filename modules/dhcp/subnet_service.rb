class Proxy::DHCP::SubnetService
  include Proxy::Log

  def self.instance_with_default_parameters
    Proxy::DHCP::SubnetService.new(Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                   Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                   Proxy::MemoryStore.new, Proxy::MemoryStore.new)
  end

  # rubocop:disable Metrics/ParameterLists
  def initialize(subnets_store, leases_ip_store, leases_mac_store, reservations_ip_store, reservations_mac_store,
      reservations_name_store)
    @subnets = subnets_store
    @leases_by_ip = leases_ip_store
    @leases_by_mac = leases_mac_store
    @reservations_by_ip = reservations_ip_store
    @reservations_by_mac = reservations_mac_store
    @reservations_by_name = reservations_name_store
  end
  # rubocop:enable Metrics/ParameterLists

  def add_subnet(subnet)
    raise Proxy::DHCP::Error, "Unable to add subnet #{subnet}" if find_subnet(subnet.network)
    logger.debug("Added a subnet: #{subnet.network}")
    @subnets[subnet.network] = subnet
  end

  def add_subnets(*subnets)
    subnets.each { |s| add_subnet(s) }
    subnets
  end

  def delete_subnet(subnet_address)
    @subnets.delete(subnet_address)
    logger.debug("Deleted a subnet: #{subnet_address}")
  end

  def find_subnet(address)
    to_ret = @subnets[address]
    return to_ret if to_ret # we were given a subnet address

    # TODO: this can be done much faster
    @subnets.values.each do |subnet|
      return subnet if subnet.include?(address)
    end

    nil
  end

  def all_subnets
    @subnets.values
  end

  def add_lease(subnet_address, record)
    @leases_by_ip[subnet_address, record.ip] = record
    @leases_by_mac[subnet_address, record.mac] = record
    logger.debug("Added a lease record: #{record.ip}:#{record.mac}")
  end

  def add_host(subnet_address, record)
    @reservations_by_ip[subnet_address, record.ip] = record
    @reservations_by_mac[subnet_address, record.mac] = record
    @reservations_by_name[record.name] = record
    logger.debug("Added a reservation: #{record.ip}:#{record.mac}:#{record.name}")
  end

  def delete_lease(record)
    @leases_by_ip.delete(record.subnet.network, record.ip)
    @leases_by_mac.delete(record.subnet.network, record.mac)
    logger.debug("Deleted a lease record: #{record.ip}:#{record.mac}")
  end

  def delete_host(record)
    @reservations_by_ip.delete(record.subnet.network, record.ip)
    @reservations_by_mac.delete(record.subnet.network, record.mac)
    @reservations_by_name.delete(record.name)
    logger.debug("Deleted a reservation: #{record.ip}:#{record.mac}:#{record.name}")
  end

  def find_lease_by_mac(subnet_address, mac_address)
    @leases_by_mac[subnet_address, mac_address]
  end

  def find_host_by_mac(subnet_address, mac_address)
    @reservations_by_mac[subnet_address, mac_address]
  end

  def find_lease_by_ip(subnet_address, ip_address)
    @leases_by_ip[subnet_address, ip_address]
  end

  def find_host_by_ip(subnet_address, ip_address)
    @reservations_by_ip[subnet_address, ip_address]
  end

  def find_host_by_hostname(hostname)
    return @reservations_by_name[hostname]
  end

  def all_hosts(subnet_address = nil)
    if subnet_address
      return @reservations_by_ip[subnet_address] ? @reservations_by_ip.values(subnet_address) : []
    end
    @reservations_by_ip.values
  end

  def all_leases(subnet_address = nil)
    if subnet_address
      return @leases_by_ip[subnet_address] ? @leases_by_ip.values(subnet_address) : []
    end
    @leases_by_ip.values
  end
end
