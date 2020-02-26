require 'dhcp_common/record'

module Proxy::DHCP
  class Reservation < Record
    attr_reader :name

    def initialize(name, ip_address, mac_address, subnet, options = {})
      @type = "reservation"
      @name = name
      super(ip_address, mac_address, subnet, {:deleteable => true}.merge(options))
    end

    def to_s
      "#{name} (#{ip} / #{mac})"
    end

    def method_missing(arg)
      options[arg]
    end

    def ==(other)
      super(other) && name == other.name
    end

    def to_json(*opts)
      Hash[[:name, :ip, :mac, :subnet, :type].map {|s| [s, send(s)]}].merge(options).to_json(*opts)
    end
  end
end
