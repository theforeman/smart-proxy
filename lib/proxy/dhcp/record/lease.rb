module Proxy::DHCP
  # represent a DHCP Lease
  class Lease < Record
    attr_reader :starts, :ends, :state

    def initialize(args = {})
      @starts = args[:starts]
      @ends = args[:ends]
      @state = args[:state]
      super(args)
    end

    def deletable?
      false
    end

    def to_json(*options)
      Hash[[:ip, :mac, :starts, :ends, :state].map{|s| [s, send(s)]}].to_json(options)
    end

  end
end
