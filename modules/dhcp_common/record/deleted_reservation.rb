require 'dhcp_common/record/reservation'

module Proxy::DHCP
  # represent a deleted DHCP Record
  class DeletedReservation < Reservation
    def initialize(name)
      @name = name
    end

    def ==(other)
      !other.nil? && self.class == other.class && name == other.name
    end
  end
end
