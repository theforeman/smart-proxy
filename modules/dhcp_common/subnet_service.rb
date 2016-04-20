module Proxy::DHCP
  class SubnetService
    include Proxy::Log

    attr_reader :m, :subnets, :leases_by_ip, :leases_by_mac, :reservations_by_ip, :reservations_by_mac, :reservations_by_name

    def initialize(subnets, leases_by_ip, leases_by_mac, reservations_by_ip, reservations_by_mac, reservations_by_name)
      @subnets = subnets
      @leases_by_ip = leases_by_ip
      @leases_by_mac = leases_by_mac
      @reservations_by_ip = reservations_by_ip
      @reservations_by_mac = reservations_by_mac
      @reservations_by_name = reservations_by_name
      @m = Monitor.new
    end

    def self.initialized_instance
      new(::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new,
          ::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new, ::Proxy::MemoryStore.new)
    end

    def add_subnet(subnet)
      m.synchronize do
        raise Proxy::DHCP::Error, "Unable to add subnet #{subnet}" if find_subnet(subnet.network)
        logger.debug("Added a subnet: #{subnet.network}")
        subnets[subnet.network] = subnet
      end
    end

    def add_subnets(*subnets)
      m.synchronize do
        subnets.each { |s| add_subnet(s) }
        subnets
      end
    end

    def delete_subnet(subnet_address)
      m.synchronize { subnets.delete(subnet_address) }
      logger.debug("Deleted a subnet: #{subnet_address}")
    end

    def find_subnet(address)
      m.synchronize do
        to_ret = subnets[address]
        return to_ret if to_ret # we were given a subnet address

        # TODO: this can be done much faster
        subnets.values.each do |subnet|
          return subnet if subnet.include?(address)
        end
      end

      nil
    end

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
