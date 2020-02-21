require 'concurrent'
require 'set'
require 'dhcp_common/pingable'

module Proxy::DHCP
  class FreeIps
    include ::Proxy::Log
    include ::Proxy::DHCP::Pingable

    DEFAULT_CLEANUP_INTERVAL = 60 # 1 min

    attr_reader :allocated_ips, :allocation_timestamps, :blacklist_interval, :m

    def initialize(blacklist_interval = 30*60)
      @blacklist_interval = blacklist_interval
      @allocated_ips = Set.new
      @allocation_timestamps = []
      @m = Monitor.new
    end

    # must be called from under the monitor
    def mark_ip_as_allocated(ip_address)
      @m.synchronize do
        @allocated_ips << ip_address
        @allocation_timestamps.push([ip_address, time_now + blacklist_interval])
      end
    end

    def clean_up_allocated_ips
      @m.synchronize do
        loop do
          logger.debug("Starting allocated ip addresses cleanup pass...")
          break if @allocation_timestamps.first.nil? || @allocation_timestamps.first[1] > time_now
          ip, _ = @allocation_timestamps.shift
          @allocated_ips.delete(ip)
          logger.debug("#{ip} marked as free.")
        end
      end
    end

    def start
      logger.info("Starting allocated ip address maintenance (used by unused_ip call).")
      @timer_task = Concurrent::TimerTask.new(:execution_interval => DEFAULT_CLEANUP_INTERVAL) { clean_up_allocated_ips }
      @timer_task.execute
    end

    def stop
      @timer_task&.shutdown
    end

    def time_now
      Time.now.to_i
    end

    def find_free_ip(from_address, to_address, records)
      start_address_i, num_of_addresses = address_range_with_start_and_end(from_address, to_address)

      record_ips = Set.new(records.collect(&:ip))
      random_index(num_of_addresses + 1) do |i|
        possible_ip = ::Proxy::DHCP.i_to_ipv4(start_address_i + i)
        next if @m.synchronize do
          if @allocated_ips.include?(possible_ip) || record_ips.include?(possible_ip)
            true
          else
            mark_ip_as_allocated(possible_ip)
            false
          end
        end
        return possible_ip unless Proxy::DhcpPlugin.settings.ping_free_ip
        begin
          logger.debug "Searching for free IP - pinging #{possible_ip}."
          if tcp_pingable?(possible_ip) || icmp_pingable?(possible_ip)
            logger.debug "Found a pingable IP(#{possible_ip}) address which does not have a Proxy::DHCP record."
          else
            logger.debug "Found free IP #{possible_ip} out of a total of #{num_of_addresses} free IPs."
            return possible_ip
          end
        rescue Exception => e
          logger.error "Exception when pinging #{possible_ip}. Skipping the address.", e
        end
      end

      logger.warn "No free IPs in range #{from_address}..#{to_address}."
      nil
    end

    def address_range_with_start_and_end(start_address, end_address)
      as_i = Proxy::DHCP.ipv4_to_i(start_address)
      [as_i, Proxy::DHCP.ipv4_to_i(end_address) - as_i]
    end

    # returns indexes for an array in random order
    def random_index(total_number_of_indices)
      raise ArgumentError.new("Zero or negative number of indices") if total_number_of_indices <= 0
      rng = Random.new(Time.now.to_i)
      past_indices = Set.new
      loop do
        break if past_indices.size >= total_number_of_indices
        current_index = rng.rand(total_number_of_indices)
        next if past_indices.add?(current_index).nil?
        yield(current_index)
      end
    end
  end
end
