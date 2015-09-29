require "dhcp/subnet"
require "proxy/validations"

module Proxy::DHCP
  # represent a DHCP Record
  class Record

    attr_reader :ip, :mac, :subnet, :options
    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize options = {}
      @subnet  = validate_subnet options[:subnet]
      @ip      = validate_ip options[:ip]
      @mac     = validate_mac options[:mac]
      @deleteable = options.delete(:deleteable) if options[:deleteable]
      @options = options
    end

    def subnet_address
      @subnet.network
    end

    def to_s
      "#{ip} / #{mac}"
    end

    def inspect
      self
    end

    def [] opt
      options[opt.to_sym]
    rescue
      nil
    end

    #TODO move this away from here, as this suppose to be a generic interface
    def deleteable?
      @deleteable
    end

    def <=>(other)
      self.ip <=> other.ip
    end

    # compare between incoming request and our existing record
    # if our record has all requested attributes then we say they are comparable
    def self.compare_options(record, request)
      request.each do |k,v|
        return false if record[k.to_sym] != v
      end
      true
    end

  end
end
