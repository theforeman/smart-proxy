module Proxy::DHCP
  # represent a DHCP Record
  class Reservation < Record

    def method_missing arg
      @options[arg]
    end

  end
end
