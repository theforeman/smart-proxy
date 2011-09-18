module Proxy::DHCP
  # represent a DHCP Record
  class Reservation < Record
    attr_reader :name

    def initialize options = {}
      @name = options[:name] || options[:hostname] || raise("Must define a name: #{options.inspect}")
      super options
    end

    def to_s
      "#{name} (#{ip} / #{mac})"
    end

    def method_missing arg
      options[arg]
    end

  end
end
