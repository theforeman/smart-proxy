module Proxy::DHCP
  require "proxy/dhcp/record"
  require "proxy/dhcp/record/lease"
  require "proxy/dhcp/record/reservation"
  require "proxy/dhcp/server"
  Optcode = {:hostname => 12, :filename => 67, :nextserver => 66}
  class Error < RuntimeError; end
  class InvalidRecord < RuntimeError; end

  def kind
    self.class.to_s.sub("Proxy::DHCP::","").downcase
  end

end
