require 'checks'
require 'ipaddr'
require 'dhcp_common/monkey_patches' unless IPAddr.new.respond_to?('to_range')
require 'dhcp_common/monkey_patch_subnet' unless Array.new.respond_to?('rotate')
require 'proxy/validations'
require 'socket'
require 'timeout'
require 'tmpdir'

module Proxy::DHCP
  # Represents a DHCP Subnet
  class Subnet
    attr_reader :network, :server, :timestamp
    attr_accessor :options

    include Proxy::DHCP
    include Proxy::Log
    include Proxy::Validations

    def initialize network, options = {}
      @network = validate_ip network
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
      if ip.is_a?(IPAddr)
        ipaddr = ip
      else
        begin
          ipaddr = IPAddr.new(ip)
        rescue
          logger.debug("Ignoring invalid IP address #{ip}")
          return false
        end
      end

      IPAddr.new(to_s).include?(ipaddr)
    end

    def to_s
      raise NotImplementedError, "Method 'to_s' must be implemented"
    end

    def prefix
      raise NotImplementedError, "Method 'prefix' must be implemented"
    end

    def netmask
      raise NotImplementedError, "Method 'netmask' must be implemented"
    end

    def valid_range
      raise NotImplementedError, "Method 'valid_range' must be implemented"
    end

    def v6?
      is_a? Proxy::DHCP::Ipv6
    end

    def range
      r = valid_range
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
      return index_from_file(@file)
    end

    def write_index_and_unlock index
      @file.reopen(@filename,'w')
      @file.write index
      @file.close
      File.delete @lockfile
    end

    def unused_ip records, args = {}
      raise NotImplementedError, "Method 'unused_ip' needs to be implemented"
    end

    def inspect
      self
    end

    def <=> other
      network <=> other.network
    end

    private

    def index_from_file file
      raise NotImplementedError, "Method 'index_from_file' needs to be implemented"
    end

    def total_range args = {}
      logger.debug "trying to find an ip address, we got #{args.inspect}"
      if args[:from] && (from = validate_ip(args[:from])) && args[:to] && (to = validate_ip(args[:to]))
        raise Proxy::DHCP::Error, "Range does not belong to provided subnet" unless self.include?(from) && self.include?(to)
        from = IPAddr.new(from)
        to   = IPAddr.new(to)
        raise Proxy::DHCP::Error, "#{from} can't be lower IP address than #{to} - change the order?" if from > to
        from..to
      else
        IPAddr.new(to_s).to_range
      end
    end

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
      system("ping -n 1 -w 1000 #{ip} > NUL")
    elsif self.is_a? Subnet::Ipv6
      # use ping6 for IPv6
      system("ping6 -c 1 -W 1 #{ip} > /dev/null")
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
end
