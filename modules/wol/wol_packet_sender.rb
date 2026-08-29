require 'socket'

module Proxy
  module Wol
    class WolPacketSender
      # Sends a Wake-on-LAN magic packet to the specified MAC address
      def self.send_magic_packet(mac_address)
        # Create magic packet using the existing method
        packet = create_magic_packet(mac_address)

        # Send UDP broadcast on port 9 (WoL standard port)
        socket = UDPSocket.new
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
        socket.send(packet, 0, '255.255.255.255', 9)
        socket.close
      end

      # Creates a magic packet for the given MAC address (useful for testing)
      def self.create_magic_packet(mac_address)
        # Clean up MAC address and convert to binary
        mac_bytes = mac_address.gsub(/[:-]/, '').scan(/../).map { |hex| hex.to_i(16) }

        # Create magic packet: 6 bytes of 0xFF followed by 16 repetitions of MAC address
        magic_packet = [0xFF] * 6 + mac_bytes * 16

        # Convert to binary string
        magic_packet.pack('C*')
      end
    end
  end
end
