module Proxy::DHCP
  class SubnetService
    include Proxy::Log

    SEARCH_MASKS = (0..31).map { |bit| ~(1 << bit) }

    attr_reader :m, :subnets, :leases_by_ip, :leases_by_mac, :reservations_by_ip, :reservations_by_mac, :reservations_by_name

    def initialize(leases_by_ip, leases_by_mac, reservations_by_ip, reservations_by_mac, reservations_by_name, subnets = {})
      @subnets = subnets
      @leases_by_ip = leases_by_ip
      @leases_by_mac = leases_by_mac
      @reservations_by_ip = reservations_by_ip
      @reservations_by_mac = reservations_by_mac
      @reservations_by_name = reservations_by_name
      @m = Monitor.new
    end

    def self.initialized_instance
      new(::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new,
          ::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new)
    end

    def add_subnet(subnet)
      m.synchronize do
        key = subnet.ipaddr.to_i
        raise Proxy::DHCP::Error, "Unable to add subnet #{subnet}" if subnets.key?(key)
        logger.debug("Added a subnet: #{subnet.network}")
        subnets[key] = subnet
        subnet
      end
    end

    def add_subnets(*subnets)
      m.synchronize do
        subnets.each { |s| add_subnet(s) }
        subnets
      end
    end

    def delete_subnet(subnet_address)
      m.synchronize { subnets.delete(Proxy::DHCP.ipv4_to_i(subnet_address)) }
      logger.debug("Deleted a subnet: #{subnet_address}")
    end

    def find_subnet(address)
      m.synchronize do
        ipv4_as_i = Proxy::DHCP.ipv4_to_i(address)
        return subnets[ipv4_as_i] if subnets.key?(ipv4_as_i)
        do_find_subnet(subnets, ipv4_as_i, address)
      end
    end

    def do_find_subnet(all_subnets, address_as_i, address)
      search_as_i = address_as_i
      SEARCH_MASKS.each do |mask|
        # zero consecutive least-significant bits until a matching prefix is found
        search_as_i &= mask
        if all_subnets.key?(search_as_i)
          matching = all_subnets[search_as_i]
          return matching if matching.netmask_to_i & address_as_i == search_as_i
        end
      end
      nil
    end
    private :do_find_subnet

    def all_subnets
      m.synchronize { subnets.values }
    end

    def add_lease(subnet_address, record)
      m.synchronize do
        leases_by_ip[subnet_address, record.ip] = record
        leases_by_mac[subnet_address, record.mac] = record
      end
      logger.debug("Added a lease record: #{record.ip}:#{record.mac}")
    end

    def add_host(subnet_address, record)
      m.synchronize do
        reservations_by_ip[subnet_address, record.ip] = record
        reservations_by_mac[subnet_address, record.mac] = record
        reservations_by_name[record.name] = record
      end
      logger.debug("Added a reservation: #{record.ip}:#{record.mac}:#{record.name}")
    end

    def delete_lease(record)
      m.synchronize do
        leases_by_ip.delete(record.subnet.network, record.ip)
        leases_by_mac.delete(record.subnet.network, record.mac)
      end
      logger.debug("Deleted a lease record: #{record.ip}:#{record.mac}")
    end

    def delete_host(record)
      m.synchronize do
        reservations_by_ip.delete(record.subnet.network, record.ip)
        reservations_by_mac.delete(record.subnet.network, record.mac)
        reservations_by_name.delete(record.name)
      end
      logger.debug("Deleted a reservation: #{record.ip}:#{record.mac}:#{record.name}")
    end

    def find_lease_by_mac(subnet_address, mac_address)
      m.synchronize { leases_by_mac[subnet_address, mac_address] }
    end

    def find_host_by_mac(subnet_address, mac_address)
      m.synchronize { reservations_by_mac[subnet_address, mac_address] }
    end

    def find_lease_by_ip(subnet_address, ip_address)
      m.synchronize { leases_by_ip[subnet_address, ip_address] }
    end

    def find_host_by_ip(subnet_address, ip_address)
      m.synchronize { reservations_by_ip[subnet_address, ip_address] }
    end

    def find_host_by_hostname(hostname)
      m.synchronize { reservations_by_name[hostname] }
    end

    def all_hosts(subnet_address = nil)
      if subnet_address
        return m.synchronize { reservations_by_ip[subnet_address] ? reservations_by_ip.values(subnet_address) : [] }
      end
      m.synchronize { reservations_by_ip.values }
    end

    def all_leases(subnet_address = nil)
      if subnet_address
        return m.synchronize { leases_by_ip[subnet_address] ? leases_by_ip.values(subnet_address) : [] }
      end
      m.synchronize { leases_by_ip.values }
    end

    def clear
      m.synchronize do
        subnets.clear
        leases_by_ip.clear
        leases_by_mac.clear
        reservations_by_ip.clear
        reservations_by_mac.clear
        reservations_by_name.clear
      end
    end

    def group_changes
      m.synchronize { yield }
    end
  end
end
