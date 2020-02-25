require 'timeout'
require 'socket'

module Proxy::DHCP::Pingable
  def tcp_pingable?(ip)
    # This code is from net-ping, and stripped down for use here
    # We don't need all the ldap dependencies net-ping brings in

    @service_check = true
    @port          = 7
    @timeout       = 1
    @exception     = nil
    bool           = false
    tcp            = nil

    begin
      Timeout.timeout(@timeout) do
        tcp = TCPSocket.new(ip, @port)
      rescue Errno::ECONNREFUSED => err
        if @service_check
          bool = true
        else
          @exception = err
        end
      rescue Exception => err
        @exception = err
      else
        bool = true
      end
    rescue Timeout::Error => err
      @exception = err
    ensure
      tcp&.close
    end

    bool
  rescue
    # We failed to check this address so we should not use it
    true
  end

  def icmp_pingable?(ip)
    # Always shell to ping, instead of using net-ping
    if RUBY_PLATFORM =~ /mingw/
      # Windows uses different options for ping and does not have /dev/null
      system("ping -n 1 -w 1000 #{ip} > NUL")
    else
      # Default to Linux ping options and send to /dev/null
      system("ping -c 1 -W 1 #{ip} > /dev/null")
    end
  rescue => err
    # We failed to check this address so we should not use it
    logger.warn "Unable to icmp ping #{ip} because #{err.inspect}. Skipping this address..."
    true
  end
end
