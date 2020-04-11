require "dhcp_common/subnet"
require "proxy/validations"

module Proxy::DHCP
  # represent a DHCP Record
  class Record
    attr_reader :ip, :mac, :subnet, :options, :type
    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize(ip_address, mac_address, subnet, options = {})
      @subnet  = validate_subnet subnet # options[:subnet]
      @ip      = validate_ip ip_address # options[:ip]
      @mac     = validate_mac mac_address # options[:mac]
      @options = options
    end

    def subnet_address
      @subnet.network
    end

    def to_s
      "#{ip} / #{mac}"
    end

    def [](opt)
      options[opt.to_sym]
    rescue
      nil
    end

    # TODO move this away from here, as this suppose to be a generic interface
    def deleteable?
      !!@options[:deleteable]
    end

    def <=>(other)
      ip <=> other.ip
    end

    def eql?(other)
      self == other
    end

    def ==(other)
      !other.nil? && self.class == other.class && ip == other.ip && mac == other.mac && subnet == other.subnet && deleteable? == other.deleteable? && options == other.options
    end
  end
end
