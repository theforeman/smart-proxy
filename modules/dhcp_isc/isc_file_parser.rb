require 'dhcp_isc/isc_common'
require 'dhcp_common/record/lease'
require 'dhcp_common/record/reservation'
require 'dhcp_common/record/deleted_reservation'

module Proxy::DHCP::ISC
  class FileParser
    include Common
    include Proxy::Validations

    attr_reader :service

    def initialize(subnet_service)
      @service = subnet_service
    end

    def parse_config_and_leases_for_records(conf)
      # Config will have host blocks,
      # Leases will have host and lease blocks.
      # Scan both together, in order, because host delete and lease end
      # events are appended linearly to the leases file.

      ret_val = []
      # scan for host statements
      conf.scan(/host\s+(\S+\s*\{[^}]+\})/) do |host|
        if match = host[0].match(/^(\S+)\s*\{([^\}]+)/)
          name = match[1]
          body  = match[2]
          opts = {:hostname => name}
          body.split(";").each do |data|
            opts.merge!(parse_record_options(data))
          end
        end
        if opts[:deleted]
          ret_val << Proxy::DHCP::DeletedReservation.new(name)
          next
        end
        next if opts[:ip].nil? || opts[:ip].empty?
        subnet = service.find_subnet(opts[:ip])
        next unless subnet
        ret_val << Proxy::DHCP::Reservation.new(name, opts.delete(:ip), opts.delete(:mac), subnet, opts)
      end

      conf.scan(/lease\s+(\S+\s*\{[^}]+\})/) do |lease|
        if match = lease[0].match(/^(\S+)\s*\{([^\}]+)/)
          next unless ip = match[1]
          body = match[2]
          opts = {}
          body.split(";").each do |data|
            opts.merge! parse_record_options(data)
          end
          next if opts[:mac].nil?
          subnet = service.find_subnet(ip)
          next unless subnet
          ret_val << Proxy::DHCP::Lease.new(nil, ip, opts.delete(:mac), subnet, opts.delete(:starts), opts.delete(:ends), opts.delete(:state), opts)
        end
      end

      ret_val
    end

    SUBNET_BLOCK_REGEX = %r{
      subnet\s+(?<subnet>[\d\.]+)\s+
      netmask\s+(?<netmask>[\d\.]+)\s*
        (?<body>
          \{
            (?:
              (?> [^{}]+ )
              |
              \g<body>
            )*
          \}
        )
      }x
    def parse_config_for_subnets(read_config)
      ret_val = []
      # Extract subnets config block
      read_config.scan(SUBNET_BLOCK_REGEX) do |match|
        network, netmask, subnet_config_lines = match
        ret_val << Proxy::DHCP::Subnet.new(network, netmask, parse_subnet_options(subnet_config_lines))
      end
      ret_val
    end

    # "pool { ... }" blocks are ignored
    POOL_BLOCK_REGEX = %r{
      pool\s*
        (?<body>
          \{
            (?:
              (?> [^{}]+ )
              |
              \g<body>
            )*
          \}
        )
      }x
    def parse_subnet_options(subnet_config_lines)
      return {} unless subnet_config_lines

      options = {}
      subnet_config_lines.gsub(POOL_BLOCK_REGEX, '').split(';').each do |option|
        option = option.split('#').first.strip # remove comments, left and right whitespace
        next if option.empty?
        case option
          when /^[\s{]*option\s+routers\s+[\d\.]+/
            options[:routers] = get_ip_list_from_config_line(option)
          when /^[\s{]*option\s+domain\-name\-servers\s+[\d\.]+/
            options[:domain_name_servers] = get_ip_list_from_config_line(option)
          when /^[\s{]*range\s+[\d\.]+\s+[\d\.]+/
            # get IP addr range used for this subnet
            options[:range] = get_range_from_config_line(option)
        end
      end

      options.reject{|key, value| value.nil? || value.empty? }
    end

    def parse_record_options text
      text = text.strip
      options = {}
      case text
        # standard record values
        when /^hardware\s+ethernet\s+(\S+)/
          options[:mac] = $1
        when /^fixed-address\s+(\S+)/
          options[:ip] = $1
        when /^next-server\s+(\S+)/
          options[:nextServer] = $1
        when /^filename\s+(\S+)/
          options[:filename] = $1
        # Lease options
        when /^binding\s+state\s+(\S+)/
          options[:state] = $1
        when /^next\s+binding\s+state\s+(\S+)/
          options[:next_state] = $1
        when /^starts\s+\d+\s+(.*)/
          options[:starts] = parse_time($1)
        when /^ends\s+\d+\s+(.*)/
          options[:ends] = parse_time($1)
        # used for failover - not implemented
        when /^tstp\s+\d+\s+(.*)/
          options[:tstp] = parse_time($1)
        # OMAPI settings
        when /^deleted/
          options[:deleted] = true
        when /^supersede server.next-server\s+=\s+(\S+)/
          begin
            ns = validate_ip hex2ip($1)
          rescue Proxy::Validations::Error
            ns = $1.gsub("\"","")
          end
          options[:nextServer] = ns
        when /^supersede server.filename\s+=\s+"(\S+)"/
          options[:filename] = $1
        when /^option\s+host-name\s+"(\S+)"/
          options[:hostname] = $1
        when /^supersede host-name\s+=\s+"(\S+)"/
          options[:hostname] = $1
        when "dynamic"
          options[:deleteable] = true
        #TODO: check if adding a new reservation with omshell for a free lease still
        #generates a conflict
      end
      options.merge!(solaris_options_parser(text))
      options
    end

    def hex2ip hex
      hex.split(":").map{|h| h.to_i(16).to_s}.join(".")
    end

    # ISC stores timestamps in UTC, therefor forcing the time to load from GMT/UTC TZ
    def parse_time str
      Time.parse(str + " UTC")
    rescue => e
      logger.warn "Unable to parse time #{e}"
      raise "Unable to parse time #{e}"
    end

    def solaris_options_parser(text)
      options = {}

      case text
        when 'vendor-option-space SUNW'
          options[:vendor] = 'sun'
        when /^option SUNW.root-server-ip-address\s+(\S+)/
          options[:root_server_ip] = $1
        when /^option SUNW.root-server-hostname\s+(\S+)/
          options[:root_server_hostname] = $1
        when /^option SUNW.root-path-name\s+(\S+)/
          options[:root_path_name] = $1
        when /^option SUNW.install-server-ip-address\s+(\S+)/
          options[:install_server_ip] = $1
        when /^option SUNW.install-server-hostname\s+(\S+)/
          options[:install_server_name] = $1
        when /^option SUNW.install-path\s+(\S+)/
          options[:install_path] = $1
        when /^option SUNW.sysid-config-file-server\s+(\S+)/
          options[:sysid_server_path] = $1
        when /^option SUNW.JumpStart-server\s+(\S+)/
          options[:jumpstart_server_path] = $1
      end
      options
    end

    # Get all IPv4 addresses provided by the ISC DHCP config line following the pattern "my-config-option-or-directive IPv4_ADDR[, IPv4_ADDR] [...];" and return an array.
    def get_ip_list_from_config_line(option_line)
      option_line.scan(/\s*((?:(?:\d{1,3}\.){3}\d{1,3})\s*(?:,\s*(?:(?:\d{1,3}\.){3}\d{1,3})\s*)*)/).first.first.gsub(/\s/,'').split(",").reject{|value| value.nil? || value.empty? }
    end

    # Get IPv4 range provided by the ISC DHCP config line following the pattern "range IPv4_ADDR IPv4_ADDR;" and return an array.
    def get_range_from_config_line(range_line)
      range_line.scan(/\s*((?:\d{1,3}\.){3}\d{1,3})\s*((?:\d{1,3}\.){3}\d{1,3})\s*/).first
    end
  end
end
