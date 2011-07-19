require "proxy/dhcp/subnet"
require "proxy/dhcp/record"

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
        return s if value.is_a?(String) and s.network == value
        return s if value.is_a?(Proxy::DHCP::Record) and s.include?(value.ip)
        return s if value.is_a?(IPAddr) and s.include?(value)
      end
      return nil
    end

    def find_record record
      subnets.each do |s|
        s.records.each do |v|
          return v if record.is_a?(String) and (v.ip == record or v.mac == record)
          return v if record.is_a?(Proxy::DHCP::Record) and v == record
          return v if record.is_a?(IPAddr) and v.ip == record.to_s
        end
      end
      return nil
    end

    def ensure_ip_and_mac_unused ip, mac
      entry = nil
      raise Proxy::DHCP::Collision, "Address #{ip} is used by this reservation: #{entry.ip} - #{entry.mac}"  if (entry = find_record(ip))
      raise Proxy::DHCP::Collision, "MAC #{mac} is used by this reservation: #{entry.mac} - #{entry.ip}"     if (entry = find_record(mac))
    end

    def inspect
      self
    end

    def addRecord options = {}
      ip = validate_ip options[:ip]
      mac = validate_mac options[:mac]
      ensure_ip_and_mac_unused ip, mac
      name = options[:hostname] || raise(Proxy::DHCP::Error, "Must provide hostname")
      raise(Proxy::DHCP::Error, "DHCP implementation does not support Vendor Options") if vendor_options_included?(options) and !vendor_options_supported?
      raise Proxy::DHCP::Error, "Unknown subnet for #{ip}" unless subnet = find_subnet(IPAddr.new(ip))
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

  end
end
