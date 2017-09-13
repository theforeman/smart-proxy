require 'time'
require 'dhcp_common/server'

module Proxy::DHCP::CommonISC
  class IscOmapiProvider < ::Proxy::DHCP::Server
    include Proxy::Util
    attr_reader :omapi_port, :key_name, :key_secret

    def initialize(server, omapi_port, subnets = nil, key_name = nil, key_secret = nil, service = nil, free_ips_service = nil)
      super(server, subnets, service, free_ips_service)
      # TODO: verify key name and secret
      @key_name = key_name
      @key_secret = key_secret
      @omapi_port = omapi_port
    end

    def del_record(record)
      validate_record record
      raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?

      om_connect
      omcmd "set hardware-address = #{record.mac}"
      omcmd "open"
      omcmd "remove"
      om_disconnect("Removed DHCP reservation for #{record.name} => #{record}")
    end

    def add_record options = {}
      record = super(options)
      om_add_record(record)
      record
    end

    def om_add_record(record)
      om_connect
      omcmd "set name = \"#{record.name}\""
      omcmd "set ip-address = #{record.ip}"
      omcmd "set hardware-address = #{record.mac}"
      omcmd "set hardware-type = 1"         # This is ethernet

      options = record.options
      # TODO: Extract this block into a generic dhcp options helper
      statements = []
      statements << "filename = \\\"#{options[:filename]}\\\";" if options[:filename]
      statements << bootServer(options[:nextServer])            if options[:nextServer]
      statements << "option host-name = \\\"#{options[:hostname] || record.name}\\\";"

      statements += solaris_options_statements(options)
      statements += ztp_options_statements(options)
      statements += poap_options_statements(options)

      omcmd "set statements = \"#{statements.join(' ')}\"" unless statements.empty?
      omcmd "create"
      om_disconnect("Added DHCP reservation for #{record}")
    end

    def om
      return @om unless @om.nil?
      om_binary = which("omshell")
      @om = IO.popen("/bin/sh -c '#{om_binary} 2>&1'", "r+")
    end

    def om_connect
      om.puts "key #{@key_name} \"#{@key_secret}\"" if @key_name && @key_secret
      om.puts "server #{name}"
      om.puts "port #{@omapi_port}"
      om.puts "connect"
      om.puts "new host"
    end

    def omcmd(command)
      logger.debug filter_log "omshell: executed - #{command}"
      om.puts(command)
    end

    def om_disconnect(msg)
      om.close_write
      status = om.readlines
      om.close
      report msg, status
      nil
    ensure
      @om = nil  # we cannot serialize an IO object, even if closed.
    end

    def report msg, response=""
      if response.nil? || (!response.empty? && !response.grep(/can't|no more|not connected|Syntax error/).empty?)
        logger.error "Omshell failed:\n" + (response.nil? ? "No response from DHCP server" : response.join(", "))
        msg.sub!(/Removed/, "remove")
        msg.sub!(/Added/, "add")
        msg.sub!(/Enumerated/, "enumerate")
        msg  = "Failed to #{msg}"
        msg += ": Entry already exists" if response && !response.grep(/object: already exists/).empty?
        msg += ": No response from DHCP server" if response.nil? || !response.grep(/not connected/).empty?
        raise Proxy::DHCP::Collision, "Hardware address conflict." if response && !response.grep(/object: key conflict/).empty?
        raise Proxy::DHCP::InvalidRecord if response && !response.grep(/can\'t open object: not found/).empty?
        raise Proxy::DHCP::Error.new(msg)
      else
        logger.debug msg
      end
    end

    def filter_log log
      secret = Proxy::DhcpPlugin.settings.dhcp_key_secret
      if secret.is_a?(String) && !secret.empty?
        log.gsub!(Proxy::DhcpPlugin.settings.dhcp_key_secret,"[filtered]")
      end
      logger.debug log
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

    def ip2hex ip
      ip.split(".").map{|i| "%02x" % i }.join(":")
    end
  end
end
