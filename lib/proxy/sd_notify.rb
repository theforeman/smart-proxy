require 'socket'

# Implementation of libsystemd's sd_notify API, sends current state via socket
module Proxy
  class SdNotify
    def active?
      !ENV['NOTIFY_SOCKET'].nil?
    end

    def notify(message)
      create_socket.tap do |socket|
        socket.sendmsg(message.chomp + "\n") # ensure trailing \n
        socket.close
      end
    end

    def ready(state = 1)
      notify("READY=#{state}")
    end

    private

    def create_socket
      raise 'Missing NOTIFY_SOCKET environment variable, is this process running under systemd?' unless active?
      Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM, 0).tap do |socket|
        socket.connect(Socket.pack_sockaddr_un(ENV['NOTIFY_SOCKET']))
      end
    end
  end
end
