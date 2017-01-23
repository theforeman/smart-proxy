require 'dhcp_common/record'

module Proxy::DHCP
  class Reservation < Record
    attr_reader :name

    def initialize(name, ip_address, mac_address, subnet, options = {})
      @name = name
      super(ip_address, mac_address, subnet, options)
    end

    def to_s
      "#{name} (#{ip} / #{mac})"
    end

    def method_missing arg
      options[arg]
    end

    def ==(other)
      super(other) && name == other.name
    end

    def to_json(*ops)
      Hash[[:name, :ip, :mac, :subnet].map{|s| [s, send(s)]}].merge(options).to_json(*opts)
    end
  end
end
