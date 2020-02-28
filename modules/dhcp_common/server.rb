require "dhcp_common/subnet"
require "dhcp_common/record"
require "dhcp_common/record/lease"
require "dhcp_common/record/reservation"
require 'dhcp_common/record/deleted_reservation'
require 'dhcp_common/pingable'
require 'proxy/logging_resolv'

module Proxy::DHCP
  class Server
    attr_reader :name, :service, :managed_subnets, :free_ips
    alias_method :to_s, :name

    include Proxy::DHCP
    include Proxy::DHCP::Pingable
    include Proxy::Log
    include Proxy::Validations
    include ::Proxy::TimeUtils
    include ::Proxy::Helpers

    def initialize(name, managed_subnets, subnet_service, free_ips_service = nil)
      @name = name
      @service = subnet_service
      @free_ips = free_ips_service
      @managed_subnets = if managed_subnets.nil?
                           Set.new
                         else
                           managed_subnets.is_a?(Enumerable) ? Set.new(managed_subnets) : Set.new([managed_subnets])
                         end
    end

    def subnets
      service.all_subnets
    end

    # Abstracted Subnet options loader method
    def load_subnet_options(subnet)
      logger.debug "Loading Subnet options for #{subnet}"
    end

    def find_subnet(subnet_address)
      service.find_subnet(subnet_address)
    end

    def get_subnet(subnet_address)
      service.find_subnet(subnet_address) || raise(Proxy::DHCP::SubnetNotFound.new("No such subnet: %s" % [subnet_address]))
    end

    def all_leases(subnet_address)
      get_subnet(subnet_address)
      service.all_leases(subnet_address)
    end

    def all_hosts(subnet_address)
      get_subnet(subnet_address)
      service.all_hosts(subnet_address)
    end

    def find_record(subnet_address, an_address)
      get_subnet(subnet_address)
      records_by_ip = find_records_by_ip(subnet_address, an_address)
      return records_by_ip.first unless records_by_ip.empty?
      find_record_by_mac(subnet_address, an_address)
    end

    def find_record_by_mac(subnet_address, mac_address)
      get_subnet(subnet_address)
      service.find_host_by_mac(subnet_address, mac_address) ||
        service.find_lease_by_mac(subnet_address, mac_address)
    end

    def find_records_by_ip(subnet_address, ip)
      get_subnet(subnet_address)
      hosts = service.find_hosts_by_ip(subnet_address, ip)
      return hosts if hosts
      lease = service.find_lease_by_ip(subnet_address, ip)
      return [lease] if lease
      []
    end

    def del_records_by_ip(subnet_address, ip)
      records = find_records_by_ip(subnet_address, ip)
      records.each { |record| del_record(record) }
      nil
    end

    def del_record_by_mac(subnet_address, mac_address)
      record = find_record_by_mac(subnet_address, mac_address)
      del_record(record) unless record.nil?
    end

    def unused_ip(subnet_address, mac_address, from_address, to_address)
      subnet = get_subnet(subnet_address)
      # first check if we already have a record for this host
      # if we do, we can simply reuse the same ip address.

      validated_from_address, validated_to_address = subnet.subnet_range_addresses(from_address, to_address)

      if mac_address
        r = find_ip_by_mac_address_and_range(subnet, mac_address, validated_from_address, validated_to_address)
        return r if r
      end

      free_ips.find_free_ip(validated_from_address, validated_to_address, all_hosts(subnet_address) + all_leases(subnet_address))
    end

    def find_ip_by_mac_address_and_range(subnet, mac_address, from_address, to_address)
      r = service.find_host_by_mac(subnet.network, mac_address) ||
          service.find_lease_by_mac(subnet.network, mac_address)

      if r && (IPAddr.new(from_address)..IPAddr.new(to_address)).cover?(IPAddr.new(r.ip))
        logger.debug "Found an existing DHCP record #{r}, reusing..."
        return r.ip
      end

      nil
    end

    def inspect
      self
    end

    # TODO: this is dhcpd-centric and should be moved out into CommonISC module

    # add_record options can take a params hash from the API layer, which behaves
    # like a HashWithIndifferentAccess to symbol and string keys.
    # Delete keys with string names before adding them back with symbol names,
    # otherwise there will be duplicate information.
    def add_record(options = {})
      related_macs = options.delete("related_macs") || []
      logger.debug "Ignoring duplicates for macs: #{related_macs.inspect}" unless related_macs.empty?

      name, ip_address, mac_address, subnet_address, options = clean_up_add_record_parameters(options)

      validate_ip(ip_address)
      validate_mac(mac_address)
      raise(Proxy::DHCP::Error, "Must provide hostname") unless name

      subnet = find_subnet(subnet_address) || raise(Proxy::DHCP::Error, "No Subnet detected for: #{subnet_address}")
      raise(Proxy::DHCP::Error, "DHCP implementation does not support Vendor Options") if vendor_options_included?(options) && !vendor_options_supported?

      to_return = Proxy::DHCP::Reservation.new(name, ip_address, mac_address, subnet, options)

      # try to figure out if we already have this record
      similar_records = find_similar_records(subnet.network, ip_address, mac_address).reject { |record| related_macs.include?(record.mac) }

      if similar_records.any? { |record| record == to_return }
        # we already got this record, no need to do anything
        logger.debug "We already got the same DHCP record - skipping"
        raise Proxy::DHCP::AlreadyExists
      end

      unless similar_records.empty?
        logger.warn "Request to create a conflicting DHCP record"
        logger.debug "request: #{to_return.inspect}"
        logger.debug "existing: #{similar_records.inspect}"
        raise Proxy::DHCP::Collision, "Record #{subnet.network}/#{ip_address} already exists"
      end

      to_return
    end

    # We ignore leases in this lookup, as isc dhcpd will allow creation of
    # reservations with the same ip and mac addresses as leases (including active ones)
    def find_similar_records(subnet_address, ip_address, mac_address)
      records = []
      records << service.find_hosts_by_ip(subnet_address, ip_address)
      records << service.find_host_by_mac(subnet_address, mac_address)
      records.flatten.compact.uniq
    end

    def clean_up_add_record_parameters(in_options)
      options = in_options.dup

      options.delete("captures")
      options.delete("splat")

      ip = options.delete("ip")
      mac = options.delete("mac")

      name = options.delete("name")
      hostname = options.delete("hostname")

      options.delete("subnet") # Not a valid key; remove it to prevent conflict with :subnet
      subnet = options.delete("network")

      # convert string keys to symbols
      options = options.each_with_object({}) { |current, all| all[current[0].to_sym] = current[1] }

      [name || hostname, ip, mac, subnet, options.merge!(:hostname => hostname || name)]
    end

    def vendor_options_included?(options)
      !options.keys.grep(/^</).empty?
    end

    def vendor_options_supported?
      false
    end

    # Default: manage any subnet. If specified: manage only specified subnets.
    def managed_subnet?(subnet)
      @managed_subnets.empty? ? true : @managed_subnets.include?(subnet)
    end
  end
end
