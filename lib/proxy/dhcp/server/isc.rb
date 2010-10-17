require 'time'
module Proxy::DHCP
  class ISC < Server

    def initialize name, config, leases
      super(name)
      @config = config
      @leases = leases
    end

    def delRecord subnet, record
      validate_subnet subnet
      validate_record record
      raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?

      omcmd "connect"
      omcmd "set hardware-address = #{record.mac}"
      omcmd "open"
      omcmd "remove"
      if omcmd("disconnect")
        logger.info "removed DHCP reservation for #{record}"
        subnet.delete record
        return true
      end
    end

    def addRecord options = {}
      msg = []
      ip = validate_ip options[:ip]
      mac = validate_mac options[:mac]
      raise Proxy::DHCP::Error, "Must provide host-name" unless options[:name]
      name = options[:name]
      raise Proxy::DHCP::Error, "Already exists" if find_record(ip)
      raise Proxy::DHCP::Error, "Unknown subnet for #{ip}" unless subnet = find_subnet(IPAddr.new(ip))

      omcmd "connect"
      omcmd "set name = \"#{name}\""
      omcmd "set ip-address = #{ip}"
      omcmd "set hardware-address = #{mac}"
      omcmd "set hardware-type = 1"         # This is ethernet

      # TODO: Extract this block into a generic dhcp options helper
      statements = []
      if options[:filename]
        statements << "filename = \\\"#{options[:filename]}\\\";"
      end
      if options[:nextserver]
        statements << "next-server = #{ip2hex options[:nextserver]};"
      end
      if name
        statements << "option host-name = \\\"#{name}\\\";"
      end

      omcmd "set statements = \"#{statements.join(" ")}\"" unless statements.empty?
      omcmd "create"
      if omcmd("disconnect")
        logger.info "created DHCP reservation for #{name} @ #{ip}/#{mac}"
        Proxy::DHCP::Reservation.new(subnet, ip, mac, options)
        return true
      end
      return false
    end

    def loadSubnetData subnet
      conf = format((@config+@leases).split("\n"))
      # scan for host statements
      conf.scan(/host\s+(\S+\s*\{[^}]+\})/) do |host|
        if host[0] =~ /^(\S+)\s*\{([^\}]+)/
          title = $1
          body  = $2
          opts = {:title => title}
          body.split(";").each do |data|
            opts.merge!(parse_record_options(data))
          end
          if opts[:deleted]
            subnet.delete find_record_by_title(subnet, title)
            next
          end
        end
        begin
          Proxy::DHCP::Reservation.new(subnet, opts[:ip], opts[:mac], opts)
        rescue Exception => e
          logger.warn "skipped #{title} - #{e}"
          false
        end
      end

      conf.scan(/lease\s+(\S+\s*\{[^}]+\})/) do |lease|
        if lease[0] =~ /^(\S+)\s*\{([^\}]+)/
          ip = $1
          body  = $2
          opts = {}
          body.split(";").each do |data|
            opts.merge! parse_record_options(data)
          end
          next if opts[:state] == "free" or ip.nil?
          Proxy::DHCP::Lease.new(opts.merge({:subnet => subnet, :ip => ip}))
        end
      end
    end

    private
    def loadSubnets
      @config.each_line do |line|
        if line =~ /^\s*subnet\s+([\d\.]+)\s+netmask\s+([\d\.]+)/
          Proxy::DHCP::Subnet.new(self, $1, $2)
        end
      end
    end

    #prepare text for parsing
    def format text
      text.delete_if {|line| line.strip.index("#") == 0}
      return text.map{|l| l.strip.chomp}.join("")
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
        options[:nextServer] = hex2ip($1)
      when /^supersede server.filename\s+=\s+"(\S+)"/
        options[:filename] = $1
      when "dynamic"
        options[:omshell] = true
        #TODO: check if adding a new reservation with omshell for a free lease still
        #generates a conflict
      end
      return options
    end

    def omcmd cmd
      status = nil
      if cmd == "connect"
        @om = IO.popen("/usr/bin/omshell", "r+")
        @om.puts "server #{name}"
        @om.puts "connect"
        @om.puts "new host"
      elsif
        cmd == "disconnect"
        @om.close_write
        status = @om.readlines
        @om.close
        @om = nil # we cannot serialize an IO obejct, even if closed.
      else
        logger.debug "omshell: executed - #{cmd}"
        @om.puts cmd
      end

      if status.to_s =~ /can't/
        logger.warn "failed to perform omshell commmand: #{status}"
        return false
      else
        return true
      end

    end

    def ip2hex ip
      ip.split(".").map{|i| "%02x" % i }.join(":")
    end

    def hex2ip hex
      hex.split(":").map{|h| h.to_i(16).to_s}.join(".")
    end

    def find_record_by_title subnet, title
      subnet.records.each do |v|
        return v if v.options[:title] == title
      end
    end

    # ISC stores timestamps in UTC, therefor forcing the time to load from GMT/UTC TZ
    def parse_time str
      Time.parse(str +" UTC")
    rescue => e
      logger.warn "Unable to parse time #{e}"
      raise "Unable to parse time #{e}"
    end

  end
end
