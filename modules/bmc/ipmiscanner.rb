require 'bmc/basescanner'
require 'concurrent'
require 'bmc/bmc_plugin'

module Proxy
  module BMC
    class IPMIScanner < BaseScanner
      include Proxy::Log
      include Proxy::Util

      # This is an IPMI ping, not an ICMP ping.
      def address_pings?(address)
        begin
          socket = UDPSocket.new
        rescue Errno::EMFILE
          logger.warn "IPMIScanner: Ran out of free file descriptors while creating UDPSocket! Consider increasing file open limit."
          retry
        end
        socket.connect(address.to_s, 623)
        socket.send([0x6, 0x0, 0xff, 0x6, 0x0, 0x0, 0x11, 0xbe, 0x80, 0x0, 0x0, 0x0].pack('C*'), 0)
        selections = IO.select([socket], nil, nil, (Proxy::BMC::Plugin.settings.bmc_scanner_socket_timeout_seconds || 1))
        socket.close
        !selections.nil?
      end

      # Not used because of slowness
      def scan_unthreaded_to_list
        return false if !valid?
        pinged = Array.new
        @range.each do |address|
          if address_pings?(address)
            pinged << address
          end
        end
        pinged
      end

      # Determine maximum number of threads
      def calculate_max_threads
        max_threads = Proxy::BMC::Plugin.settings.bmc_scanner_max_threads_per_request || 500
        begin
          sockets = Array.new
          # @range.first(max_threads).size performs much better than @range.count if @range is large.
          (1..[max_threads, @range.first(max_threads).size].min).each do
            socket = UDPSocket.new
            sockets << socket
          end
        rescue Errno::EMFILE
          # Running low on free file descriptors; only allow use of half of the remaining
          max_threads = [sockets.length / 2, 1].max
          # Clean up sockets
          sockets.each do |sock|
            sock.close
          end
          logger.warn "IPMIScanner: Running low on free file descriptors! Can only allocate #{sockets.length}, so using #{max_threads} to avoid hitting the limit."
        end
        max_threads
      end

      def scan_threaded_to_list
        return false if !valid?
        pinged = Array.new
        pool = Concurrent::ThreadPoolExecutor.new(max_threads: calculate_max_threads)
        @range.each do |address|
          pool.post do
            if address_pings?(address)
              pinged << address
            end
          end
        end
        pool.shutdown
        pool.wait_for_termination
        pinged
      end

      def scan_to_list
        return false if !valid?
        scan_threaded_to_list
      end
    end
  end
end
