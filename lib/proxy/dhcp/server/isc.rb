require 'time'
module Proxy::DHCP
  class ISC < Server

    def initialize options
      super(options[:name])
      @config = options[:config]
      @leases = options[:leases]
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
      ip = validate_ip options[:ip]
      mac = validate_mac options[:mac]
      raise Proxy::DHCP::Error, "Must provide host-name" unless options[:name]
      name = options[:name]
      raise Proxy::DHCP::Error, "Already exists" if find_record(ip)
      raise Proxy::DHCP::Error, "Unknown subnet for #{ip}" unless subnet = find_subnet(IPAddr.new(ip))

      msg = "Added DHCP reservation for #{options[:name]}"
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
      omcmd("disconnect")
      Proxy::DHCP::Reservation.new(subnet, ip, mac, options)
    end

    def loadSubnetData subnet
      super
      conf = format((@config+@leases).split("\n"))
      # scan for host statements
      conf.scan(/host\s+(\S+\s*\{[^}]+\})/) do |host|
        if match = host[0].match(/^(\S+)\s*\{([^\}]+)/)
          title = match[1]
          body  = match[2]
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
        end
      end

      conf.scan(/lease\s+(\S+\s*\{[^}]+\})/) do |lease|
        if match = lease[0].match(/^(\S+)\s*\{([^\}]+)/)
          ip   = match[1]
          body = match[2]
          opts = {}
          body.split(";").each do |data|
            opts.merge! parse_record_options(data)
          end
          next if opts[:state] == "free" or ip.nil?
          Proxy::DHCP::Lease.new(opts.merge({:subnet => subnet, :ip => ip}))
        end
      end
      report "Enumerated hosts on #{subnet.network}"
    end

    private
    def loadSubnets
      @config.each_line do |line|
        if line =~ /^\s*subnet\s+([\d\.]+)\s+netmask\s+([\d\.]+)/
          Proxy::DHCP::Subnet.new(self, $1, $2)
        end
      end
      "Enumerated the scopes on #{@name}"
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

    def omcmd cmd, msg=nil
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
        @om = nil # we cannot serialize an IO object, even if closed.
      else
        logger.debug "omshell: executed - #{cmd}"
        @om.puts cmd
      end

      report msg, status
    end

    def report msg, response=""
      if response.to_s =~ /can't|no more/
       logger.error "Omshell failed:\n" + status
        msg.sub! /Removed/,    "remove"
        msg.sub! /Added/,      "add"
        msg.sub! /Enumerated/, "enumerate"
        msg  = "Failed to #{msg}"
        raise Proxy::DHCP::Error.new(msg)
      else
        logger.info msg
      end
    rescue
      logger.error "Omshell failed:\n" + status
      raise Proxy::DHCP::Error.new("Unknown error while processing '#{msg}'")
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
