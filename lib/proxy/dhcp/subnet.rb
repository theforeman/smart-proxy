require 'checks'
require 'ipaddr'
require 'proxy/dhcp/monkey_patches' unless IPAddr.new.respond_to?('to_range')
require 'proxy/dhcp/monkey_patch_subnet' unless Array.new.respond_to?('rotate')
require 'proxy/validations'
require 'socket'
require 'timeout'
require 'tmpdir'

module Proxy::DHCP
  # Represents a DHCP Subnet
  class Subnet
    attr_reader :network, :netmask, :server, :timestamp
    attr_accessor :options

    include Proxy::DHCP
    include Proxy::DHCP::Fileop
    include Proxy::Log
    include Proxy::Validations

    def initialize server, network, netmask
      @server    = validate_server server
      @network   = validate_ip network
      @netmask   = validate_ip netmask
      @options   = {}
      @records   = {}
      @timestamp = Time.now
      @loaded    = false
      raise Proxy::DHCP::Error, "Unable to Add Subnet" unless @server.add_subnet(self)
    end

    def include? ip
      IPAddr.new(to_s).include?(ip.is_a?(IPAddr) ? ip : IPAddr.new(ip))
    end

    def to_s
      "#{network}/#{netmask}"
    end

    def cidr
      IPAddr.new(netmask).to_i.to_s(2).count("1")
    end

    def range
      r=valid_range
      "#{r.first.to_s}-#{r.last.to_s}"
    end

    def clear
      @records = {}
      @loaded  = false
    end

    def loaded?
      @loaded
    end

    def size
      records.size
    end

    def load
      self.clear
      return false if loaded?
      @loaded = true
      server.loadSubnetData self
      logger.debug "Lazy loaded #{to_s} records"
    end

    def reload
      clear
      self.load
    end

    def records
      self.load if not loaded?
      @records.values
    end

    def [] record
      self.load if not loaded?
      begin
        return has_mac?(record) if validate_mac(record)
      rescue
        nil
      end
      begin
        return has_ip?(record) if validate_ip(record)
      rescue
        nil
      end
    end

    def has_mac? mac
      records.each {|r| return r if r.mac == mac.downcase }
      return false
    end

    def has_ip? ip
      @records[ip] ? @records[ip] : false
    end

    # adds a record to a subnet
    def add_record record
      unless has_mac?(record.mac) or has_ip?(record.ip)
        @records[record.ip] = record
        logger.debug "Added #{record} to #{to_s}"
        return true
      end
      logger.warn "Record #{record} already exists in #{to_s} - can't add again"
      return false
    end

    # returns the next unused IP Address in a subnet
    # Pings the IP address as well (just in case its not in Proxy::DHCP)
    def unused_ip args = {}
      # first check if we already have a record for this host
      # if we do, we can simply reuse the same ip address.
      if args[:mac] and r=has_mac?(args[:mac])
        logger.debug "Found an existing dhcp record #{r}, reusing..."
        return r.ip
      end

      free_ips = valid_range(args) - records.collect{|r| r.ip}
      if free_ips.empty?
        logger.warn "No free IPs at #{to_s}"
        return nil
      else
        @index = 0
        begin
          # Read and lock the storage file
          stored_index = get_index_and_lock("foreman-proxy_#{network}_#{cidr}.tmp")

          free_ips.rotate(stored_index).each do |ip|
            logger.debug "Searching for free ip - pinging #{ip}"
            if tcp_pingable?(ip) or icmp_pingable?(ip)
              logger.info "Found a pingable IP(#{ip}) address which does not have a Proxy::DHCP record"
            else
              logger.debug "Found free ip #{ip} out of a total of #{free_ips.size} free ips"
              @index = free_ips.index(ip)+1
              return ip
            end
          end
          logger.warn "No free IPs at #{to_s}"
        rescue Exception => e
          logger.debug e.message
        ensure
          # ensure we unlock the storage file
          set_index_and_unlock @index
        end
        nil
      end
    end

    def delete record
      if @records.delete_if{|k,v| v == record}.nil?
        raise Proxy::DHCP::Error, "Removing a Proxy::DHCP Record which doesn't exists"
      end
    end

    def valid_range args = {}
      logger.debug "trying to find an ip address, we got #{args.inspect}"
      if args[:from] and (from=validate_ip(args[:from])) and args[:to] and (to=validate_ip(args[:to]))
        raise Proxy::DHCP::Error, "Range does not belong to provided subnet" unless self.include?(from) and self.include?(to)
        from = IPAddr.new(from)
        to   = IPAddr.new(to)
        raise Proxy::DHCP::Error, "#{from} can't be lower IP adderss then #{to} - chage the order?" if from > to
        from..to
      else
        IPAddr.new(to_s).to_range
      # remove broadcast and network address
      end.map(&:to_s) - [network, broadcast]
    end

    def inspect
      self
    end

    def reservations
      records.collect{|r| r if r.kind == "reservation"}.compact
    end

    def leases
      records.collect{|r| r if r.kind == "lease"}.compact
    end

    def <=> other
      network <=> other.network
    end

    def broadcast
      IPAddr.new(to_s).to_range.last.to_s
    end

    private
    def tcp_pingable? ip
      # This code is from net-ping, and stripped down for use here
      # We don't need all the ldap dependencies net-ping brings in

      @service_check = true
      @port          = 7
      @timeout       = 1
      @exception     = nil
      bool           = false
      tcp            = nil

      begin
        Timeout.timeout(@timeout){
          begin
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
        }
      rescue Timeout::Error => err
        @exception = err
      ensure
        tcp.close if tcp
      end

      bool
    rescue
      # We failed to check this address so we should not use it
      true
    end

    def icmp_pingable? ip
      # Always shell to ping, instead of using net-ping
      system("ping -c 1 -W 1 #{ip} > /dev/null")
    rescue
      # We failed to check this address so we should not use it
      true
    end

    def privileged_user
      (PLATFORM =~ /linux/i and Process.uid == 0) or PLATFORM =~ /mingw/
    end
  end
end
