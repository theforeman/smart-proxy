require 'yaml'
require 'json'
require 'monitor'
require 'concurrent'
require 'time'
require 'externalipam/ipam_helper'
require 'singleton'

module Proxy::Ipam
  # Class for managing temp in-memory cache to prevent same IP's being suggested in race conditions
  class IpCache
    include Singleton
    include Proxy::Log
    include Proxy::Ipam::IpamHelper

    DEFAULT_CLEANUP_INTERVAL = 180

    def initialize
      @m = Monitor.new
      @ip_cache = {'': {}}
      start_cleanup_task
    end

    def provider_name(provider)
      @provider = provider
    end

    def get_cidr(group_name, cidr)
      @ip_cache.dig(group_name, cidr)
    end

    def get_ip(group_name, cidr, mac)
      @ip_cache.dig(group_name, cidr, mac, :ip)
    end

    def ip_exists?(group_name, cidr, ip)
      subnet_hash = get_cidr(group_name, cidr)
      return false if subnet_hash.nil?
      subnet_hash&.any? { |mac, cached_ip| cached_ip[:ip] == ip }
    end

    def ip_expired?(group_name, cidr, ip)
      return true unless ip_exists?(group_name, cidr, ip)
      subnet_hash = get_cidr(group_name, cidr)
      subnet_hash&.any? { |mac, cached_ip| cached_ip[:ip] == ip && expired(cached_ip[:timestamp]) }
    end

    def cleanup_interval
      DEFAULT_CLEANUP_INTERVAL
    end

    def add(group_name, cidr, ip, mac = nil)
      logger.debug("Adding IP '#{ip}' to cache for subnet '#{cidr}' in group '#{group_name}' for IPAM provider #{@provider}")
      @m.synchronize do
        mac_addr = mac.nil? || mac.empty? ? SecureRandom.uuid : mac
        group_hash = @ip_cache[group_name]

        if group_hash&.key?(cidr)
          @ip_cache[group_name][cidr][mac_addr] = { ip: ip.to_s, timestamp: Time.now }
        else
          @ip_cache[group_name] = { cidr => { mac_addr => { ip: ip.to_s, timestamp: Time.now }}}
        end
      end
    end

    private

    def expired(ip_expiration)
      Time.now - ip_expiration > DEFAULT_CLEANUP_INTERVAL
    end

    def start_cleanup_task
      logger.info("Starting ip cache maintenance for External IPAM provider, used by /next_ip.")
      @timer_task = Concurrent::TimerTask.new(execution_interval: DEFAULT_CLEANUP_INTERVAL) { clean_cache }
      @timer_task.execute
    end

    # @ip_cache structure
    #
    # Groups of subnets are cached under the External IPAM Group name. For example,
    # "IPAM Group Name" would be the section name in phpIPAM. All IP's cached for subnets
    # that do not have an External IPAM group specified, they are cached under the "" key. IP's
    # are cached using one of two possible keys:
    #    1). Mac Address
    #    2). UUID (Used when Mac Address not specified)
    #
    # {
    #   "": {
    #     "192.0.2.0/24":{
    #       "00:0a:95:9d:68:10": {"ip": "192.0.2.1", "timestamp": "2019-09-17 12:03:43 -D400"},
    #       "906d8bdc-dcc0-4b59-92cb-665935e21662": {"ip": "192.0.2.2", "timestamp": "2019-09-17 11:43:22 -D400"}
    #     },
    #   },
    #   "IPAM Group Name": {
    #     "198.51.100.0/24":{
    #       "00:0a:95:9d:68:33": {"ip": "198.51.100.1", "timestamp": "2019-09-17 12:04:43 -0400"},
    #       "00:0a:95:9d:68:34": {"ip": "198.51.100.2", "timestamp": "2019-09-17 12:05:48 -0400"},
    #       "00:0a:95:9d:68:35": {"ip": "198.51.100.3", "timestamp:: "2019-09-17 12:06:50 -0400"}
    #     }
    #   },
    #   "Another IPAM Group": {
    #     "203.0.113.0/24":{
    #       "00:0a:95:9d:68:55": {"ip": "203.0.113.1", "timestamp": "2019-09-17 12:04:43 -0400"},
    #       "00:0a:95:9d:68:56": {"ip": "203.0.113.2", "timestamp": "2019-09-17 12:05:48 -0400"}
    #     }
    #   }
    # }
    def clean_cache
      @m.synchronize do
        entries_deleted = 0
        total_entries = 0

        @ip_cache.each do |group, subnets|
          subnets.each do |cidr, macs|
            macs.each do |mac, ip|
              if expired(ip[:timestamp])
                @ip_cache[group][cidr].delete(mac)
                entries_deleted += 1
              end
              total_entries += 1
            end
            @ip_cache[group].delete(cidr) if @ip_cache[group][cidr].nil? || @ip_cache[group][cidr].empty?
            @ip_cache.delete(group) if @ip_cache[group].nil? || @ip_cache[group].empty?
          end
        end

        cache_count = total_entries - entries_deleted
        logger.debug("Removing #{entries_deleted} entries from IP cache for IPAM provider #{@provider}") if entries_deleted > 0
        logger.debug("Current count of IP cache entries for IPAM provider #{@provider}: #{cache_count}") if entries_deleted > 0
      end
    end
  end
end
