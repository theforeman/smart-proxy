require 'dhcp_common/subnet'

module Proxy::DHCP
  class Ipv4 < Subnet
    attr_reader :netmask

    def initialize network, netmask, options = {}
      @netmask = validate_ip netmask
      super network, options
    end

    def to_s
      "#{network}/#{netmask}"
    end

    # NOTE: stored index is indepndent of call parameters:
    # Whether range is passed or not, the lookup starts with the address at the indexed position,
    # Is the assumption that unused_ip is always called with the same parameters for a given subnet?
    #
    # returns the next unused IP Address in a subnet
    # Pings the IP address as well (just in case its not in Proxy::DHCP)
    def unused_ip records, args = {}
      free_ips = valid_range(args) - records.collect{|record| record.ip}
      if free_ips.empty?
        logger.warn "No free IPs at #{self}"
        return nil
      else
        @index = 0
        begin
          # Read and lock the storage file
          stored_index = get_index_and_lock("foreman-proxy_#{network}_#{prefix}.tmp")
          free_ips.rotate(stored_index).each do |ip|
            logger.debug "Searching for free IP - pinging #{ip}"
            if tcp_pingable?(ip) || icmp_pingable?(ip)
              logger.debug "Found a pingable IP(#{ip}) address which does not have a Proxy::DHCP record"
            else
              logger.debug "Found free IP #{ip} out of a total of #{free_ips.size} free IPs"
              @index = free_ips.index(ip) + 1
              return ip
            end
          end
          logger.warn "No free IPs at #{self}"
        rescue Exception => e
          logger.debug e.message
        ensure
          # ensure we unlock the storage file
          write_index_and_unlock @index
        end
        nil
      end
    end

    def prefix
      IPAddr.new(netmask).to_i.to_s(2).count("1")
    end

    def valid_range args = {}
      total_range(args).map(&:to_s) - [network, broadcast]
    end

    def broadcast
      IPAddr.new(to_s).to_range.last.to_s
    end

    private

    def index_from_file file
      file.readlines.first.to_i rescue 0
    end
  end
end
