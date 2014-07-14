require 'time'
module Proxy::DHCP
  class ISC < Server
    include Proxy::Util

    def initialize options
      super(options[:name])
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
      subnet.delete record
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

      omcmd "set statements = \"#{statements.join(" ")}\""      unless statements.empty?
      omcmd "create"
      omcmd("disconnect", "Added DHCP reservation for #{record}")
      record
    end

    def loadSubnetData subnet
      super

      # Config will have host blocks,
      # Leases will have host and lease blocks.
      # Scan both together, in order, because host delete and lease end
      # events are appended linearly to the leases file.
      conf = @config + @leases

      # scan for host statements
      conf.scan(/host\s+(\S+\s*\{[^}]+\})/) do |host|
        if match = host[0].match(/^(\S+)\s*\{([^\}]+)/)
          hostname = match[1]
          body  = match[2]
          opts = {:hostname => hostname}
          body.split(";").each do |data|
            opts.merge!(parse_record_options(data))
          end
          if opts[:deleted]
            record = find_record_by_hostname(subnet, hostname)
            subnet.delete record if record
            next
          end
        end
        begin
          Proxy::DHCP::Reservation.new(opts.merge({:subnet => subnet})) if subnet.include? opts[:ip]
        rescue Exception => e
          logger.warn "skipped #{hostname} - #{e}"
        end
      end

      conf.scan(/lease\s+(\S+\s*\{[^}]+\})/) do |lease|
        if match = lease[0].match(/^(\S+)\s*\{([^\}]+)/)
          next unless ip = match[1]
          body = match[2]
          opts = {}
          body.split(";").each do |data|
            opts.merge! parse_record_options(data)
          end
          next if opts[:state] == "free" or opts[:state] == "abandoned" or opts[:mac].nil?
          Proxy::DHCP::Lease.new(opts.merge({:subnet => subnet, :ip => ip})) if subnet.include? ip
        end
      end
      report "Enumerated hosts on #{subnet.network}"
    end

    private

    def loadSubnets
      super
      @config.scan(/subnet\s+([\d\.]+)\s+netmask\s+([\d\.]+)/) do |match|
        next unless managed_subnet? "#{match[0]}/#{match[1]}"

        Proxy::DHCP::Subnet.new(self, match[0], match[1])
      end
      "Enumerated the scopes on #{@name}"
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
        @om.puts "key #{Proxy::DhcpPlugin.settings.dhcp_key_name} \"#{Proxy::DhcpPlugin.settings.dhcp_key_secret}\"" if Proxy::DhcpPlugin.settings.dhcp_key_name and Proxy::DhcpPlugin.settings.dhcp_key_secret
        @om.puts "server #{name}"
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
      if response.nil? or (!response.empty? and !response.grep(/can't|no more|not connected|Syntax error/).empty?)
        logger.error "Omshell failed:\n" + (response.nil? ? "No response from DHCP server" : response.join(", "))
        msg.sub! /Removed/,    "remove"
        msg.sub! /Added/,      "add"
        msg.sub! /Enumerated/, "enumerate"
        msg  = "Failed to #{msg}"
        msg += ": Entry already exists" if response and response.grep(/object: already exists/).size > 0
        msg += ": No response from DHCP server" if response.nil? or response.grep(/not connected/).size > 0
        raise Proxy::DHCP::Collision, "Hardware address conflict." if response and response.grep(/object: key conflict/).size > 0
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

    def find_record_by_hostname subnet, hostname
      subnet.records.find do |v|
        v.options[:hostname] == hostname
      end
    end

    # ISC stores timestamps in UTC, therefor forcing the time to load from GMT/UTC TZ
    def parse_time str
      Time.parse(str +" UTC")
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
      if secret.is_a?(String) and not secret.empty?
        log.gsub!(Proxy::DhcpPlugin.settings.dhcp_key_secret,"[filtered]")
      end
      logger.debug log
    end

    def read_config file, ignore_includes=false
      logger.debug "Reading config file #{file}"
      config = []
      File.readlines(file).each do |line|

        line.strip! # remove left and right whitespace
        next if line.start_with?("#") # remove comments
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
  end
end
