require "dhcp/subnet"
require "dhcp/record"
require "dhcp/record/lease"
require "dhcp/subnet_service"

module Proxy::DHCP
  # represents a DHCP Server
  class Server
    attr_reader :name
    alias_method :to_s, :name

    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize(name, service)
      @name    = name
      @loaded  = false
      @service = service
    end

    def subnets
      @service.all_subnets
    end

    # Abstracted Subnet loader method
    def loadSubnets
      logger.debug "Loading subnets for #{name}"
    end

    # Abstracted Subnet data loader method
    def loadSubnetData subnet
      raise "Invalid Subnet" unless subnet.is_a? Proxy::DHCP::Subnet
      logger.debug "Loading subnet data for #{subnet}"
    end

    # Abstracted Subnet options loader method
    def loadSubnetOptions subnet
      logger.debug "Loading Subnet options for #{subnet}"
    end

    def find_subnet subnet_address
      @service.find_subnet(subnet_address)
    end

    def all_leases(subnet)
      @service.all_leases(subnet)
    end

    def all_hosts(subnet)
      @service.all_hosts(subnet)
    end

    def find_record(subnet_address, an_address)
      @service.find_host_by_ip(subnet_address, an_address) ||
        @service.find_host_by_mac(subnet_address, an_address) ||
        @service.find_lease_by_ip(subnet_address, an_address) ||
        @service.find_lease_by_mac(subnet_address, an_address)
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
      r = @service.find_host_by_mac(subnet.network, mac_address) ||
          @service.find_lease_by_mac(subnet.network, mac_address)

      if r && subnet.valid_range(:from => from_address, :to => to_address).include?(r.ip)
        logger.debug "Found an existing dhcp record #{r}, reusing..."
        return r.ip
      end
    end

    def inspect
      self
    end

    # addRecord options can take a params hash from the API layer, which behaves
    # like a HashWithIndifferentAccess to symbol and string keys.
    # Delete keys with string names before adding them back with symbol names,
    # otherwise there will be duplicate information.
    def addRecord options = {}
      # dup the hash before modifying it locally
      options = options.dup
      options.delete("captures")
      options.delete("splat")

      ip = validate_ip options.delete("ip")
      mac = validate_mac options.delete("mac")

      name = options.delete("name")
      hostname = options.delete("hostname")
      raise(Proxy::DHCP::Error, "Must provide hostname") unless hostname || name

      options.delete("subnet") # Not a valid key; remove it to prevent conflict with :subnet
      net = options.delete("network")
      subnet = find_subnet(net) || raise(Proxy::DHCP::Error, "No Subnet detected for: #{net.inspect}")
      raise(Proxy::DHCP::Error, "DHCP implementation does not support Vendor Options") if vendor_options_included?(options) && !vendor_options_supported?

      options.merge!(:hostname => hostname || name, :subnet => subnet, :ip => ip, :mac => mac)

      # try to figure out if we already have this record
      record = @service.find_host_by_ip(subnet.network, ip) || @service.find_host_by_mac(subnet.network, mac)
      unless record.nil?
        if Record.compare_options(record.options, options)
          # we already got this record, no need to do anything
          logger.debug "We already got the same DHCP record - skipping"
          raise Proxy::DHCP::AlreadyExists
        else
          logger.warn "Request to create a conflicting record"
          logger.debug "request: #{options.inspect}"
          logger.debug "local:   #{record.options.inspect}"
          raise Proxy::DHCP::Collision, "Record #{net}/#{ip} already exists"
        end
      end

      Proxy::DHCP::Reservation.new(options)
    end

    def vendor_options_included? options
      !(options.keys.grep(/^</).empty?)
    end

    def vendor_options_supported?
      false
    end

    # Default: manage any subnet. If specified: manage only specified subnets.
    def managed_subnet? subnet
      managed_subnets = Proxy::DhcpPlugin.settings.dhcp_subnets
      return true unless managed_subnets
      managed_subnets.include? subnet
    end
  end
end
