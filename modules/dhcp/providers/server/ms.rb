require 'dhcp/subnet'
require 'dhcp/record'
require 'dhcp/server'

module Proxy::DHCP
  # Represents Microsoft DHCP Server
  # requires the help of a CGI like script running on a MS IIS Server
  class MS < Server

    def initialize(options = {})
      super options[:server]
      @username = options[:username]
      @password = options[:password]
      @gateway  = options[:gateway]
    end

    def loadSubnets
      super
      cmd = "ListScopeDetailed"
      operand = "enumerate the scopes on #{@name}"

      response = query cmd, operand

      response.each do |line|
        line.chomp
        break if line.match(/^Command completed/)

        # 172.29.216.0   - 255.255.254.0  -Active        -DC BRS               -
        if line =~ /^\s*([\d\.]+)\s*-\s*([\d\.]+)\s*-\s*(Active|Disabled)/
          network = $1
          netmask = $2
          Proxy::DHCP::Subnet.new(self, network, netmask)
        end
      end
    end

    def loadSubnetData subnet
      raise "invalid Subnet" unless subnet.is_a? Proxy::DHCP::Subnet
      cmd = "ListReservation" + "&ScopeIpAddress=#{subnet.network}"
      operand = "enumerate #{subnet.network} on #{@name}"

      response = query cmd, operand

      subnet.clear

      # Extract the data
      response.each do |line|
        line.chomp
        break if line.match(/^Command completed/)
        #     172.29.216.6      -    00-a0-e7-21-41-00-
        if line =~ /^\s+([\w\.]+)\s+-\s+([-a-f\d]+)/
          ip = $1
          mac = $2.gsub(/-/,":").match(/^(.*?).$/)[1]
          Proxy::DHCP::Record.new(subnet, ip, mac) unless ip.nil? || mac.nil?
        end
      end
      super subnet
    end


    def loadSubnetOptions subnet
      raise "invalid Subnet" unless subnet.is_a? Proxy::DHCP::Subnet
      cmd = "ShowOptionValue&ScopeIPAddress=#{subnet.network}"
      response = query cmd

      subnet.options = parse_options response
      super subnet
    end

    def loadRecordOptions record
      raise "invalid Record" unless record.is_a? Proxy::DHCP::Record
      subnet = record.subnet
      raise "unable to find subnet for #{record}" if subnet.nil?
      cmd = "ShowReservedOptionValue&ScopeIPAddress=#{subnet.network}&ReservedIP=#{record.ip}"
      response = query cmd

      record.options = parse_options response
    end

    def delRecordFor record
      subnet = find_subnet record
      mac    = record.mac.gsub(/:/,"")
      entry  = "ScopeIpAddress=#{subnet.network}&ReservedIP=#{record.ip}"
      cmd = "DeleteReservation&#{entry}&MAC_Address=#{mac}"

      query cmd
      logger.info "removed Proxy::DHCP reservation for #{entry}/#{mac}"
      subnet.delete(record)
    end

    private
    def query cmd, operand = nil
      response = invoke cmd
      validate_response cmd, operand, response
      return response
    end

    def invoke cmd
      userAgent = 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; SV1; .NET CLR 1.1.4322; .NET CLR 1.0.3705; .NET CLR 2.0.50727; InfoPath.1; MS-RTC LM 8)'
      header  = "https://#{@gateway}/NetShManager/NetShManager.aspx?ServerName=#{@name}&"
      cmd     = "CommandName=/" + cmd
      command = "curl -q -k --silent --user '#{@username}:#{@password}' --user-agent '#{userAgent}' '#{header}#{cmd}'; "
      filtered = command.gsub(@password,"FILTERED")
      puts "Invoking #{filtered}" if @@debug

      response = %x{#{command}}
      puts response if @@debug
      raise Proxy::DHCP::Error, "invalid Response - curl return error code #{$?} - while executing #{filtered}" unless $? == 0
      return $? == 0 ? response.split(/\r\n/) : false
    end

    def validate_response cmd, operand, response
      unless response[-3..-2].join=~/Command completed successfully/
        logger.error "Invoke failed:\n" + response.join("\n")
        scopeIpAddress, ip = cmd.match(/ScopeIpAddress=([^&]+)&ReservedIP=([^&]+)/)[1..2]

        case operand
        when /^create|^delete/
          msg = "Failed to #{operand} for #{ip} in #{scopeIpAddress}"
        when /^enumerate|install/
          msg = "Failed to #{operand}"
        when /^query/
          return response if response[2] =~ /not a reserved client/
        else
          if cmd.match(/Add/)
            msg = "Failed to set #{operand} for #{ip} in #{scopeIpAddress}"
          else
            msg = "Failed to get option values for #{ip} in #{scopeIpAddress}"
          end
        end
      end
      raise Proxy::DHCP::Error.new msg if msg
    rescue
      raise Proxy::DHCP::Error.new "Unknown error while processing #{msg} - #{response}"
    end

    def parse_options response
     optionId = nil
     options = {}
      response.each do |line|
        line.chomp
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
