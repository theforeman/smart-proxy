require "dhcp/subnet"
require "dhcp/record"
require "dhcp/record/lease"

module Proxy::DHCP
  # represents a DHCP Server
  class Server
    attr_reader :name
    alias_method :to_s, :name

    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize(name)
      @name    = name
      @subnets = []
      @loaded  = false
    end

    def loaded?
      @loaded
    end

    def clear
      @subnets = []
      @loaded  = false
    end

    def load
      self.clear
      @loaded = true
      loadSubnets
    end

    def subnets
      self.load if not loaded?
      @subnets
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

    # Adds a Subnet to a server object
    def add_subnet subnet
      if find_subnet(subnet.network).nil?
        @subnets << validate_subnet(subnet)
        logger.debug "Added #{subnet} to #{name}"
        return true
      end
      logger.warn "Subnet #{subnet} already exists in server #{name}"
      return false
    end

    def find_subnet value
      subnets.each do |s|
        return s if value.is_a?(String) && s.network == value
        return s if value.is_a?(Proxy::DHCP::Record) && s.include?(value.ip)
        return s if value.is_a?(IPAddr) && s.include?(value)
      end
      return nil
    end

    def find_record record
      subnets.each do |s|
        s.records.each do |v|
          return v if record.is_a?(String) && (v.ip == record || v.mac == record)
          return v if record.is_a?(Proxy::DHCP::Record) && v == record
          return v if record.is_a?(IPAddr) && v.ip == record.to_s
        end
      end
      return nil
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
      record = find_record(ip) || find_record(mac)
      unless record.nil? || record.is_a?(Proxy::DHCP::Lease)
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

    def delRecord subnet, record
      subnet.delete record
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
