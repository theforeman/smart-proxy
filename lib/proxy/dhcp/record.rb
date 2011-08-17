require "proxy/dhcp/subnet"
require "proxy/validations"

module Proxy::DHCP
  # represent a DHCP Record
  class Record

    attr_reader :ip, :mac, :subnet
    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize(subnet, ip, mac, options = nil)
      @subnet  = validate_subnet subnet
      @ip      = validate_ip ip
      @mac     = validate_mac mac.downcase
      @options = options
      @subnet.add_record(self)
      @deleteable = @options.delete(:omshell) if @options and @options[:omshell]
    end

    def to_s
      "#{ip} / #{mac}"
    end

    def inspect
      self
    end

    def options= value
      @options = value
    end

    def options
      @options || subnet.server.loadRecordOptions(self).merge(:mac => mac, :ip => ip)
    end

    def [] opt
      @options[opt]
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
