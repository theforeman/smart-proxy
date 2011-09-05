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

  end
end
