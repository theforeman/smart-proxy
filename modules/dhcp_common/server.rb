require "dhcp_common/subnet"
require "dhcp_common/record"
require "dhcp_common/record/lease"
require "dhcp_common/record/reservation"
require 'dhcp_common/record/deleted_reservation'

module Proxy::DHCP
  class Server
    attr_reader :name, :service, :managed_subnets
    alias_method :to_s, :name

    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize(name, managed_subnets, subnet_service)
      @name = name
      @service = subnet_service
      @managed_subnets = if managed_subnets.nil?
                           Set.new
                         else
                           managed_subnets.is_a?(Enumerable) ? Set.new(managed_subnets) : Set.new([managed_subnets])
                         end
    end

    def subnets
      service.all_subnets
    end

    # Abstracted Subnet loader method
    def load_subnets
      logger.debug "Loading subnets for #{name}"
    end

    # Abstracted Subnet data loader method
    def load_subnet_data subnet
      raise "Invalid Subnet" unless subnet.is_a? Proxy::DHCP::Subnet
      logger.debug "Loading subnet data for #{subnet}"
    end

    # Abstracted Subnet options loader method
    def load_subnet_options subnet
      logger.debug "Loading Subnet options for #{subnet}"
    end

    def find_subnet subnet_address
      service.find_subnet(subnet_address)
    end

    def all_leases(subnet)
      service.all_leases(subnet)
    end

    def all_hosts(subnet)
      service.all_hosts(subnet)
    end

    def find_record(subnet_address, an_address)
      service.find_host_by_ip(subnet_address, an_address) ||
        service.find_host_by_mac(subnet_address, an_address) ||
        service.find_lease_by_ip(subnet_address, an_address) ||
        service.find_lease_by_mac(subnet_address, an_address)
    end

    def unused_ip(subnet, mac_address, from_address, to_address)
      # first check if we already have a record for this host
      # if we do, we can simply reuse the same ip address.
      if mac_address
        r = ip_by_mac_address_and_range(subnet, mac_address, from_address, to_address)
        return r if r
      end

      subnet.unused_ip(all_hosts(subnet.network) + all_leases(subnet.network),
                       :from => from_address, :to => to_address)
    end

    def ip_by_mac_address_and_range(subnet, mac_address, from_address, to_address)
      r = service.find_host_by_mac(subnet.network, mac_address) ||
          service.find_lease_by_mac(subnet.network, mac_address)

      if r && subnet.valid_range(:from => from_address, :to => to_address).include?(r.ip)
        logger.debug "Found an existing DHCP record #{r}, reusing..."
        return r.ip
      end
    end

    def inspect
      self
    end

    # add_record options can take a params hash from the API layer, which behaves
    # like a HashWithIndifferentAccess to symbol and string keys.
    # Delete keys with string names before adding them back with symbol names,
    # otherwise there will be duplicate information.
    def add_record options = {}
      options = clean_up_add_record_parameters(options)

      validate_ip(options[:ip])
      validate_mac(options[:mac])
      raise(Proxy::DHCP::Error, "Must provide hostname") unless options[:hostname]

      subnet = find_subnet(options[:subnet]) || raise(Proxy::DHCP::Error, "No Subnet detected for: #{options[:subnet]}")
      options[:subnet] = subnet

      raise(Proxy::DHCP::Error, "DHCP implementation does not support Vendor Options") if vendor_options_included?(options) && !vendor_options_supported?

      # try to figure out if we already have this record
      record = service.find_host_by_ip(subnet.network, options[:ip]) || service.find_host_by_mac(subnet.network, options[:mac])
      unless record.nil?
        if Record.compare_options(record.options, options)
          # we already got this record, no need to do anything
          logger.debug "We already got the same DHCP record - skipping"
          raise Proxy::DHCP::AlreadyExists
        else
          logger.warn "Request to create a conflicting DHCP record"
          logger.debug "request: #{options.inspect}"
          logger.debug "local:   #{record.options.inspect}"
          raise Proxy::DHCP::Collision, "Record #{subnet.network}/#{options[:ip]} already exists"
        end
      end

      Proxy::DHCP::Reservation.new(options)
    end

    def clean_up_add_record_parameters(in_options)
      to_return = in_options.dup

      to_return.delete("captures")
      to_return.delete("splat")

      ip = to_return.delete("ip")
      mac = to_return.delete("mac")

      name = to_return.delete("name")
      hostname = to_return.delete("hostname")

      to_return.delete("subnet") # Not a valid key; remove it to prevent conflict with :subnet
      subnet = to_return.delete("network")

      to_return.merge!(:hostname => hostname || name, :subnet => subnet, :ip => ip, :mac => mac)
    end

    def vendor_options_included? options
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
