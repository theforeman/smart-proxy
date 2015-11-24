require 'dhcp/record/reservation'

module Proxy::DHCP
  # represent a deleted DHCP Record
  class DeletedReservation < Reservation
    attr_reader :name

    def initialize options = {}
      @name = options[:name] || options[:hostname] || raise("Must define a name: #{options.inspect}")
      @options = options
    end
  end
end
