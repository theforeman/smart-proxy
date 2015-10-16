require 'checks'
require 'ipaddr'
require 'dhcp/monkey_patches' unless IPAddr.new.respond_to?('to_range')
require 'dhcp/monkey_patch_subnet' unless Array.new.respond_to?('rotate')
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
    include Proxy::Log
    include Proxy::Validations

    def initialize network, netmask, options = {}
      @network = validate_ip network
      @netmask = validate_ip netmask
      @options = {}

      @options[:routers] = options[:routers].each{|ip| validate_ip ip } if options[:routers]
      @options[:domain_name] = options[:domain_name] if options[:domain_name]
      @options[:domain_name_servers] = options[:domain_name_servers].each{|ip| validate_ip ip } if options[:domain_name_servers]
      @options[:ntp_servers] = options[:ntp_servers].each{|ip| validate_ip ip } if options[:ntp_servers]
      @options[:interface_mtu] = options[:interface_mtu].to_i if options[:interface_mtu]
      @options[:range] = options[:range] if options[:range] && options[:range][0] && options[:range][1] && valid_range(:from => options[:range][0], :to => options[:range][1])

      @timestamp     = Time.now
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
      "#{r.first}-#{r.last}"
    end

    def get_index_and_lock filename
      # Store for use in the unlock method
      @filename = "#{Dir::tmpdir}/#{filename}"
      @lockfile = "#{@filename}.lock"

      # Loop if the file is locked
      Timeout::timeout(30) { sleep 0.1 while File.exist? @lockfile }

      # Touch the lock the file
      File.open(@lockfile, "w") {}

      @file = File.new(@filename,'r+') rescue File.new(@filename,'w+')

      # this returns the index in the file
      return @file.readlines.first.to_i rescue 0
    end

    def write_index_and_unlock index
      @file.reopen(@filename,'w')
      @file.write index
      @file.close
      File.delete @lockfile
    end

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
          stored_index = get_index_and_lock("foreman-proxy_#{network}_#{cidr}.tmp")

          free_ips.rotate(stored_index).each do |ip|
            logger.debug "Searching for free IP - pinging #{ip}"
            if tcp_pingable?(ip) || icmp_pingable?(ip)
              logger.info "Found a pingable IP(#{ip}) address which does not have a Proxy::DHCP record"
            else
              logger.debug "Found free IP #{ip} out of a total of #{free_ips.size} free IPs"
              @index = free_ips.index(ip)+1
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

    def valid_range args = {}
      logger.debug "trying to find an ip address, we got #{args.inspect}"
      if args[:from] && (from=validate_ip(args[:from])) && args[:to] && (to=validate_ip(args[:to]))
        raise Proxy::DHCP::Error, "Range does not belong to provided subnet" unless self.include?(from) && self.include?(to)
        from = IPAddr.new(from)
        to   = IPAddr.new(to)
        raise Proxy::DHCP::Error, "#{from} can't be lower IP address than #{to} - change the order?" if from > to
        from..to
      else
        IPAddr.new(to_s).to_range
      # remove broadcast and network address
      end.map(&:to_s) - [network, broadcast]
    end

    def inspect
      self
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
        Timeout.timeout(@timeout) do
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
        end
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
    if PLATFORM =~ /mingw/
      # Windows uses different options for ping and does not have /dev/null
      system("ping -n 1 -w 1 #{ip} > NUL")
    else
      # Default to Linux ping options and send to /dev/null
      system("ping -c 1 -W 1 #{ip} > /dev/null")
    end
    rescue
      # We failed to check this address so we should not use it
      true
    end

    def privileged_user
      (PLATFORM =~ /linux/i && Process.uid == 0) || PLATFORM =~ /mingw/
    end
  end
end
