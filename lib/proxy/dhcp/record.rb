require "proxy/dhcp/subnet"
require "proxy/validations"

module Proxy::DHCP
  # represent a DHCP Record
  class Record

    attr_reader :ip, :mac, :subnet
    attr_accessor :options
    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize(subnet, ip, mac, options = {})
      @subnet = validate_subnet subnet
      @ip = validate_ip ip
      @mac = validate_mac mac.downcase
      @options = options
      @subnet.add_record(self)
    end

    def to_s
      "#{ip} / #{mac}"
    end

    def inspect
      self
    end

    def [] opt
      @options[opt]
    end

    #TODO move this away from here, as this suppose to be a generic interface
    def deleteable?
      return true unless options[:omshell]
      options[:omshell]
    end

    def <=>(other)
      self.ip <=> other.ip
    end

  end
end
