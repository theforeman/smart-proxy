module ::Proxy::DHCP::ISC
  module Common
    def ip2hex ip
      ip.split(".").map{|i| "%02x" % i }.join(":")
    end
  end
end
