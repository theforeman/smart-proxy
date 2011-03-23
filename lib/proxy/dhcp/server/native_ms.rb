require 'rubygems'
require 'win32/open3'

module Proxy::DHCP
  # Represents Microsoft DHCP Server manipulated via the netsh command
  # executed on a Microsoft server under a service account
  class NativeMS < Server

    def initialize(options = {})
      super options[:server]
    end

    def delRecord subnet, record
      validate_subnet subnet
      validate_record record
      # TODO: Refactor this into the base class
      raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?

      mac = record.mac.gsub(/:/,"")
      msg = "Removed DHCP reservation for #{record.name} => #{record.ip} - #{record.mac}"
      cmd = "scope #{subnet.network} delete reservedip #{record.ip} #{mac}"

      execute(cmd, msg)
      subnet.delete(record)
    end

    def addRecord options={}
      ip   = validate_ip options[:ip]
      mac  = validate_mac options[:mac]
      name = options[:hostname] || raise(Proxy::DHCP::Error, "Must provide hostname")
      raise Proxy::DHCP::Error, "Already exists" if find_record(ip)
      raise Proxy::DHCP::Error, "Unknown subnet for #{ip}" unless subnet = find_subnet(IPAddr.new(ip))

      msg = "Added DHCP reservation for #{name} => #{ip} - #{mac}"
      cmd = "scope #{subnet.network} add reservedip #{ip} #{mac.gsub(/:/,"")} #{name}"
      execute(cmd, msg)

      return if options[:nextserver].nil?  # This reservation is just for an IP and MAC

      # TODO: Refactor these execs into a popen
      cmd = "scope #{subnet.network} set reservedoptionvalue #{ip} #{Optcode[:filename]}   String #{options[:filename]}"
      execute(cmd, msg, true)

      cmd = "scope #{subnet.network} set reservedoptionvalue #{ip} #{Optcode[:nextserver]} String #{options[:nextserver]}"
      execute(cmd, msg, true)

      cmd = "scope #{subnet.network} set reservedoptionvalue #{ip} #{Optcode[:hostname]}   String #{options[:hostname]}"
      execute(cmd, msg, true)

      record = Proxy::DHCP::Reservation.new subnet, ip, mac, options
      true
    end

    def loadSubnetData subnet
      super
      cmd = "scope #{subnet.network} show reservedip"
      msg = "Enumerated hosts on #{subnet.network}"

      # Extract the data
      execute(cmd, msg).each do |line|
        #     172.29.216.6      -    00-a0-e7-21-41-00-
        if line =~ /^\s+([\w\.]+)\s+-\s+([-a-f\d]+)/
          ip  = $1
          mac = $2.gsub(/-/,":").match(/^(.*?).$/)[1]
          begin
            Proxy::DHCP::Reservation.new(subnet, ip, mac)
          rescue Exception => e
            logger.warn "Skipped #{line} - #{e}"
          end
        end
      end
    end

    def loadSubnetOptions subnet
      super subnet
      raise "invalid Subnet" unless subnet.is_a? Proxy::DHCP::Subnet
      cmd = "scope #{subnet.network} Show OptionValue"
      msg = "Queried #{subnet.network} options"

      subnet.options = parse_options(execute(cmd, msg))
    end

    def loadRecordOptions record
      raise "invalid Record" unless record.is_a? Proxy::DHCP::Record
      subnet = record.subnet
      raise "unable to find subnet for #{record}" if subnet.nil?
      cmd = "scope #{subnet.network} Show ReservedOptionValue #{record.ip}"
      msg = "Queried #{record.name} options"

      record.options = parse_options(execute(cmd, msg))
    end


    private
    def loadSubnets
      super
      cmd = "show scope"
      msg = "Enumerated the scopes on #{@name}"

      execute(cmd, msg).each do |line|
        # 172.29.216.0   - 255.255.254.0  -Active        -DC BRS               -
        if match = line.match(/^\s*([\d\.]+)\s*-\s*([\d\.]+)\s*-\s*(Active|Disabled)/)
          subnet = Proxy::DHCP::Subnet.new(self, match[1], match[2])
        end
      end
    end

    def execute cmd, msg=nil, error_only=false
      tsecs = 5
      response = nil
      interpreter = SETTINGS.x86_64 ? 'c:\windows\sysnative\cmd.exe' : 'c:\windows\system32\cmd.exe'
      command  = interpreter + ' /c c:\Windows\System32\netsh.exe -c dhcp ' + "server #{name} #{cmd}"

      std_in = std_out = std_err = nil
      begin
        timeout(tsecs) do
          std_in, std_out, std_err  = Open3.popen3(command)
          response  = std_out.readlines
          response += std_err.readlines
        end
      rescue TimeoutError
        raise Proxy::DHCP::Error.new("Netsh did not respond within #{tsecs} seconds")
      ensure
        std_in.close  unless std_in.nil?
        std_out.close unless std_in.nil?
        std_err.close unless std_in.nil?
      end
      report msg, response, error_only
      response
    end

    def report msg, response, error_only
      if response.grep(/completed successfully/).empty?
        logger.error "Netsh failed:\n" + response.join("\n")
        msg.sub! /Removed/,    "remove"
        msg.sub! /Added/,      "add"
        msg.sub! /Enumerated/, "enumerate"
        msg.sub! /Queried/,    "query"
        match = ""
        msg  = "Failed to #{msg}"
        msg += ": No entry found" if response.grep(/not a reserved client/).size > 0
        msg += ": #{match}" if (match = response.grep(/used by another client/)).size > 0
        raise Proxy::DHCP::Error.new(msg)
      else
        logger.info msg unless error_only
      end
    rescue Proxy::DHCP::Error
      raise
    rescue
      logger.error "Netsh failed:\n" + (response.is_a?(Array) ? response.join("\n") : "Response was not an array! #{response}")
      raise Proxy::DHCP::Error.new("Unknown error while processing '#{msg}'")
    end

    def parse_options response
      optionId = nil
      options = {}
      response.each do |line|
        line.chomp!
        break if line.match(/^Command completed/)

        case line
        when /OptionId : (\d+)/
          optionId = $1
        when /Option Element Value = (\S+)/
          options[optionId] = $1
        end
      end
      return options
    end
  end
end
