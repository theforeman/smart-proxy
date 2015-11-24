require 'time'
require 'dhcp/subnet'
require 'dhcp/record/deleted_reservation'
require 'dhcp/record/reservation'
require 'dhcp/record/lease'
require 'dhcp/server'

module Proxy::DHCP
  class ISC < Server
    include Proxy::Util

    def self.instance_with_default_parameters
        Proxy::DHCP::ISC.new(:name => Proxy::DhcpPlugin.settings.dhcp_server,
                             :config => Proxy::DhcpPlugin.settings.dhcp_config,
                             :leases => Proxy::DhcpPlugin.settings.dhcp_leases,
                             :service => Proxy::DHCP::SubnetService.instance_with_default_parameters)
    end

    def initialize options
      super(options[:name], options[:service])
      @config = read_config(options[:config]).join("")
      @leases = read_config(options[:leases], true).join("")
    end

    def delRecord subnet, record
      validate_subnet subnet
      validate_record record
      raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?

      msg = "Removed DHCP reservation for #{record.name} => #{record}"
      omcmd "connect"
      omcmd "set hardware-address = #{record.mac}"
      omcmd "open"
      omcmd "remove"
      omcmd("disconnect", msg)
    end

    def addRecord options = {}
      record = super(options)

      omcmd "connect"
      omcmd "set name = \"#{record.name}\""
      omcmd "set ip-address = #{record.ip}"
      omcmd "set hardware-address = #{record.mac}"
      omcmd "set hardware-type = 1"         # This is ethernet

      options = record.options
      # TODO: Extract this block into a generic dhcp options helper
      statements = []
      statements << "filename = \\\"#{options[:filename]}\\\";"  if options[:filename]
      statements << bootServer(options[:nextServer])             if options[:nextServer]
      statements << "option host-name = \\\"#{record.name}\\\";" if record.name

      statements += solaris_options_statements(options)
      statements += ztp_options_statements(options)
      statements += poap_options_statements(options)

      omcmd "set statements = \"#{statements.join(' ')}\""      unless statements.empty?
      omcmd "create"
      omcmd("disconnect", "Added DHCP reservation for #{record}")
      record
    end

    def parse_config_and_leases_for_records
      # Config will have host blocks,
      # Leases will have host and lease blocks.
      # Scan both together, in order, because host delete and lease end
      # events are appended linearly to the leases file.
      conf = @config + @leases

      ret_val = []
      # scan for host statements
      conf.scan(/host\s+(\S+\s*\{[^}]+\})/) do |host|
        if match = host[0].match(/^(\S+)\s*\{([^\}]+)/)
          hostname = match[1]
          body  = match[2]
          opts = {:hostname => hostname}
          body.split(";").each do |data|
            opts.merge!(parse_record_options(data))
          end
        end
        if opts[:deleted]
          ret_val << Proxy::DHCP::DeletedReservation.new(opts)
          next
        end
        subnet = @service.find_subnet(opts[:ip])
        next unless subnet
        ret_val << Proxy::DHCP::Reservation.new(opts.merge(:subnet => subnet))
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

          subnet = @service.find_subnet(ip)
          next unless subnet
          ret_val << Proxy::DHCP::Lease.new(opts.merge(:subnet => subnet, :ip => ip))
        end
      end

      ret_val
    end

    def initialize_memory_store_with_dhcp_records(records)
      records.each do |record|
        case record
        when Proxy::DHCP::DeletedReservation
          record = @service.find_host_by_hostname(record.name)
          @service.delete_host(record) if record
          next
        when Proxy::DHCP::Reservation
          if dupe = @service.find_host_by_mac(record.subnet_address, record.mac)
            @service.delete_host(dupe)
          end
          if dupe = @service.find_host_by_ip(record.subnet_address, record.ip)
            @service.delete_host(dupe)
          end

          @service.add_host(record.subnet_address, record)
        when Proxy::DHCP::Lease
          if record.options[:state] == "free" || (record.options[:next_state] == "free" && record.options[:ends] && record.options[:ends] < Time.now)
            record = @service.find_lease_by_ip(record.subnet_address, record.ip)
            @service.delete_lease(record) if record
            next
          end

          if dupe = @service.find_lease_by_mac(record.subnet_address, record.mac)
            @service.delete_lease(dupe)
          end
          if dupe = @service.find_lease_by_ip(record.subnet_address, record.ip)
            @service.delete_lease(dupe)
          end

          @service.add_lease(record.subnet_address, record)
        end
      end
    end

    def loadSubnetData subnet
      initialize_memory_store_with_dhcp_records(parse_config_and_leases_for_records)
    end

    SUBNET_BLOCK_REGEX = /subnet\s+([\d\.]+)\s+netmask\s+([\d\.]+)\s*\{\s*([\w-]+\s*\{[^{}]*\}\s*|[\w-][^{}]*;\s*)*\}/
    def parse_config_for_subnets
      ret_val = []
      # Extract subnets config block
      @config.scan(SUBNET_BLOCK_REGEX) do |match|
        network, netmask, subnet_config_lines = match
        ret_val << Proxy::DHCP::Subnet.new(network, netmask, parse_subnet_options(subnet_config_lines))
      end
      ret_val
    end

    def parse_subnet_options(subnet_config_lines)
      return {} unless subnet_config_lines

      options = {}
      subnet_config_lines.split(';').each do |option|
        case option
          when /^option\s+routers\s+[\d\.]+/
            options[:routers] = get_ip_list_from_config_line(option)
          when /^option\s+domain\-name\-servers\s+[\d\.]+/
            options[:domain_name_servers] = get_ip_list_from_config_line(option)
          when /^range\s+[\d\.]+\s+[\d\.]+/
            # get IP addr range used for this subnet
            options[:range] = get_range_from_config_line(option)
        end
      end

      options.reject{|key, value| value.nil? || value.empty? }
    end

    def loadSubnets
      super
      @service.add_subnets(*parse_config_for_subnets)
    end

    def parse_record_options text
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
        rescue
          ns = $1.gsub("\"","")
        end
        options[:nextServer] = ns
      when /^supersede server.filename\s+=\s+"(\S+)"/
        options[:filename] = $1
      when "dynamic"
        options[:deleteable] = true
        #TODO: check if adding a new reservation with omshell for a free lease still
        #generates a conflict
      end
      options.merge!(solaris_options_parser(text))
      options
    end

    def omcmd cmd, msg=nil
      if cmd == "connect"
        om_binary = which("omshell")
        @om = IO.popen("/bin/sh -c '#{om_binary} 2>&1'", "r+")
        @om.puts "key #{Proxy::DhcpPlugin.settings.dhcp_key_name} \"#{Proxy::DhcpPlugin.settings.dhcp_key_secret}\"" if Proxy::DhcpPlugin.settings.dhcp_key_name && Proxy::DhcpPlugin.settings.dhcp_key_secret
        @om.puts "server #{name}"
        @om.puts "port #{Proxy::DhcpPlugin.settings.dhcp_omapi_port}"
        @om.puts "connect"
        @om.puts "new host"
      elsif cmd == "disconnect"
        @om.close_write
        status = @om.readlines
        @om.close
        @om = nil # we cannot serialize an IO object, even if closed.
        report msg, status
      else
        logger.debug filter_log "omshell: executed - #{cmd}"
        @om.puts cmd
      end
    end

    def report msg, response=""
      if response.nil? || (!response.empty? && !response.grep(/can't|no more|not connected|Syntax error/).empty?)
        logger.error "Omshell failed:\n" + (response.nil? ? "No response from DHCP server" : response.join(", "))
        msg.sub!(/Removed/, "remove")
        msg.sub!(/Added/, "add")
        msg.sub!(/Enumerated/, "enumerate")
        msg  = "Failed to #{msg}"
        msg += ": Entry already exists" if response && response.grep(/object: already exists/).size > 0
        msg += ": No response from DHCP server" if response.nil? || response.grep(/not connected/).size > 0
        raise Proxy::DHCP::Collision, "Hardware address conflict." if response && response.grep(/object: key conflict/).size > 0
        raise Proxy::DHCP::InvalidRecord if response && response.grep(/can\'t open object: not found/).size > 0
        raise Proxy::DHCP::Error.new(msg)
      else
        logger.info msg
      end
    end

    def ip2hex ip
      ip.split(".").map{|i| "%02x" % i }.join(":")
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

    def bootServer server
      begin
        ns = ip2hex validate_ip(server)
      rescue
        begin
          ns = ip2hex Resolv.new.getaddress(server)
        rescue
          logger.warn "Failed to resolve IP address for #{server}"
          ns = "\\\"#{server}\\\""
        end
      end
      "next-server = #{ns};"
    end

    def filter_log log
      secret = Proxy::DhcpPlugin.settings.dhcp_key_secret
      if secret.is_a?(String) && !secret.empty?
        log.gsub!(Proxy::DhcpPlugin.settings.dhcp_key_secret,"[filtered]")
      end
      logger.debug log
    end

    def read_config file, ignore_includes=false
      logger.debug "Reading config file #{file}"
      config = []
      File.readlines(file).each do |line|
        line = line.split('#').first.strip # remove comments, left and right whitespace
        next if line.empty? # remove blank lines

        if /^include\s+"(.*)"\s*;/ =~ line
          conf = $1
          unless File.exist?(conf)
            next if ignore_includes
            raise "Unable to find the included DHCP configuration file: #{conf}"
          end
          # concat modifies the receiver rather than creating a new array
          # and does not create a multidimensional array
          config.concat(read_config(conf, ignore_includes))
        else
          config << line
        end
      end
      config
    end

    def vendor_options_supported?
      true
    end

    def solaris_options_statements(options)
      # Solaris options defined in Foreman app/models/operatingsystems/solaris.rb method jumpstart_params
      # options example
      # {"hostname"                                      => ["itgsyddev910.macbank"],
      #  "mac"                                           => ["00:21:28:6d:62:e8"],
      #  "ip"                                            => ["10.229.11.38"],
      #  "network"                                       => ["10.229.11.0"],
      #  "nextServer"                                    => ["10.229.11.24"], "filename" => ["Solaris-5.10-hw0811-sun4v-inetboot"],
      #  "<SPARC-Enterprise-T5120>root_path_name"        => ["/Solaris/install/Solaris_5.10_sparc_hw0811/Solaris_10/Tools/Boot"],
      #  "<SPARC-Enterprise-T5120>sysid_server_path"     => ["10.229.11.24:/Solaris/jumpstart/sysidcfg/sysidcfg_primary"],
      #  "<SPARC-Enterprise-T5120>install_server_ip"     => ["10.229.11.24"],
      #  "<SPARC-Enterprise-T5120>jumpstart_server_path" => ["10.229.11.24:/Solaris/jumpstart"],
      #  "<SPARC-Enterprise-T5120>install_server_name"   => ["itgsyddev807.macbank"],
      #  "<SPARC-Enterprise-T5120>root_server_hostname"  => ["itgsyddev807.macbank"],
      #  "<SPARC-Enterprise-T5120>root_server_ip"        => ["10.229.11.24"],
      #  "<SPARC-Enterprise-T5120>install_path"          => ["/Solaris/install/Solaris_5.10_sparc_hw0811"] }
      #
      statements = []
      options.each do |key, value|
        next unless (match = key.to_s.match(/^<([^>]+)>(.*)/))
        vendor, attr = match[1, 2].map(&:to_sym)
        next unless vendor.to_s =~ /sun|solar|sparc/i
        case attr
          when :jumpstart_server_path
            statements << "option SUNW.JumpStart-server \\\"#{value}\\\";"
          when :sysid_server_path
            statements << "option SUNW.sysid-config-file-server \\\"#{value}\\\";"
          when :install_server_name
            statements << "option SUNW.install-server-hostname \\\"#{value}\\\";"
          when :install_server_ip
            statements << "option SUNW.install-server-ip-address #{value};"
          when :install_path
            statements << "option SUNW.install-path \\\"#{value}\\\";"
          when :root_server_hostname
            statements << "option SUNW.root-server-hostname \\\"#{value}\\\";"
          when :root_server_ip
            statements << "option SUNW.root-server-ip-address #{value};"
          when :root_path_name
            statements << "option SUNW.root-path-name \\\"#{value}\\\";"
        end
      end

      statements << 'vendor-option-space SUNW;' if statements.join(' ') =~ /SUNW/

      statements
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

    # Quirk: Junos ZTP requires special DHCP options
    def ztp_options_statements(options)
      statements = []
      if options[:filename] && options[:filename].match(/^ztp.cfg.*/i)
        logger.debug "setting ZTP options"
        opt150 = ip2hex validate_ip(options[:nextServer])
        statements << "option option-150 = #{opt150};"
        statements << "option FM_ZTP.config-file-name = \\\"#{options[:filename]}\\\";"
      end
      statements
    end

    # Cisco NX-OS POAP requires special DHCP options
    def poap_options_statements(options)
      statements = []
      if options[:filename] && options[:filename].match(/^poap.cfg.*/i)
        logger.debug "setting POAP options"
        statements << "option tftp-server-name = \\\"#{options[:nextServer]}\\\";"
        statements << "option bootfile-name = \\\"#{options[:filename]}\\\";"
      end
      statements
    end
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
