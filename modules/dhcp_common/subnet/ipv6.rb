require 'dhcp_common/subnet'
require 'dhcp_common/monkey_patches' unless IPAddr.new.respond_to?('to_mask')

module Proxy::DHCP
  class Ipv6 < Subnet
    attr_reader :prefix

    def initialize network, prefix, options = {}
      @prefix = validate_v6_prefix prefix
      super network, options
    end

    def to_s
      "#{network}/#{prefix}"
    end

    def netmask
      IPAddr.new(network).mask(prefix).to_mask
    end

    def next_ipaddr(range, ip)
      if ip == 0
        range.first
      else
        IPAddr.new(ip).mask(range.first.to_mask)
      end
    end

    def valid_range args = {}
      # TODO - handle reserved addresses
      # and change the first line in unused_ip
      true
    end

    def unused_ip records, args = {}
      current_range = total_range(args)

      begin
        stored_ip = get_index_and_lock("foreman-proxy_#{network}_#{prefix}.tmp")
        candidate_ipaddr = next_ipaddr(current_range, stored_ip)
        first_ipaddr = candidate_ipaddr
        while true
          candidate_ipaddr = current_range.first if candidate_ipaddr.to_i > current_range.last.to_i
          ip = candidate_ipaddr.to_s
          if tcp_pingable?(ip) || icmp_pingable?(ip)
            logger.debug "Found a pingable IP(#{ip}) address which does not have a Proxy::DHCP record"
          else
            logger.debug "Found free IP #{ip}"
            @index = candidate_ipaddr.succ.to_s
            return ip
          end
          candidate_ipaddr = candidate_ipaddr.succ
          break if candidate_ipaddr == first_ipaddr
        end
        logger.warn "No free IPs at #{self}"
      rescue Exception => e
        logger.debug e.message
      ensure
        write_index_and_unlock @index
      end
      nil
    end

    private

    def index_from_file file
      file.readline rescue 0
    end
  end
end
