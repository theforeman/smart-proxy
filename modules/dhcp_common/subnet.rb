require 'ipaddr'
require 'dhcp_common/monkey_patches' unless IPAddr.new.respond_to?('to_range')
require 'dhcp_common/monkey_patch_subnet' unless Array.new.respond_to?('rotate')
require 'proxy/validations'
require 'tmpdir'
require 'dhcp_common/pingable'

module Proxy::DHCP
  class Subnet
    attr_reader :ipaddr, :network, :netmask, :server
    attr_accessor :options

    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations
    include Proxy::DHCP::Pingable

    def initialize(network, netmask, options = {})
      @network = validate_ip network
      @netmask = validate_ip netmask
      @ipaddr = IPAddr.new(to_s)
      @options = {}

      @options[:routers] = options[:routers].each { |ip| validate_ip ip } if options[:routers]
      @options[:domain_name] = options[:domain_name] if options[:domain_name]
      @options[:domain_name_servers] = options[:domain_name_servers] if options[:domain_name_servers]
      @options[:ntp_servers] = options[:ntp_servers] if options[:ntp_servers]
      @options[:interface_mtu] = options[:interface_mtu].flatten.first.to_i if options[:interface_mtu]
      @options[:range] = options[:range] if options[:range] && options[:range][0] && options[:range][1] && validate_subnet_range!(options[:range][0], options[:range][1])

      @m = Monitor.new
    end

    def include?(ip)
      if ip.is_a?(IPAddr)
        ipaddr = ip
      else
        begin
          ipaddr = IPAddr.new(ip)
        rescue
          logger.debug("Ignoring invalid IP address #{ip}")
          return false
        end
      end

      @ipaddr.include?(ipaddr)
    end

    def to_s
      "#{network}/#{netmask}"
    end

    def cidr
      netmask_to_i.to_s(2).count("1")
    end

    def range
      range_start, range_end = subnet_range_addresses
      "#{range_start}-#{range_end}"
    end

    def netmask_to_i
      @netmask_to_i ||= Proxy::DHCP.ipv4_to_i(netmask)
    end

    def validate_subnet_range!(from_address, to_address)
      if (from=validate_ip(from_address)) && (to=validate_ip(to_address))
        raise Proxy::DHCP::Error, "Range does not belong to provided subnet" unless self.include?(from) && self.include?(to)
        from = IPAddr.new(from)
        to   = IPAddr.new(to)
        raise Proxy::DHCP::Error, "#{from} can't be lower IP address than #{to} - change the order?" if from > to
      end
      true
    end

    def subnet_range_addresses(from_address = nil, to_address = nil)
      validate_subnet_range!(from_address, to_address) if !from_address.nil? && !to_address.nil?

      network_address_as_i = ::Proxy::DHCP.ipv4_to_i(network)
      mask_as_i = ::Proxy::DHCP.ipv4_to_i(netmask)

      subnet_start_address = (network_address_as_i & mask_as_i) + 1
      subnet_end_address = network_address_as_i | (0xffffffff ^ mask_as_i) - 1

      from_address_as_i = from_address.nil? ? 0 : ::Proxy::DHCP.ipv4_to_i(from_address)
      to_address_as_i = to_address.nil? ? 0xffffffff : ::Proxy::DHCP.ipv4_to_i(to_address)

      range_start_address = (from_address_as_i < subnet_start_address) ? subnet_start_address : from_address_as_i
      range_end_address = (to_address_as_i > subnet_end_address) ? subnet_end_address : to_address_as_i

      [::Proxy::DHCP.i_to_ipv4(range_start_address), ::Proxy::DHCP.i_to_ipv4(range_end_address)]
    end

    def <=>(other)
      network <=> other.network
    end

    def ==(other)
      network == other.network && netmask == other.netmask && options == other.options
    end

    def eql?(other)
      self == other
    end

    def broadcast
      IPAddr.new(to_s).to_range.last.to_s
    end
  end
end
