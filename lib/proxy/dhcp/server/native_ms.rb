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
      record = super(options)

      cmd = "scope #{record.subnet.network} add reservedip #{record.ip} #{record.mac.gsub(/:/,"")} #{record.name}"
      execute(cmd, "Added DHCP reservation for #{record}")

      options = record.options
      options.delete_if{|k,v| k == :ip or k == :mac or k == :name }
      return if options.empty?  # This reservation is just for an IP and MAC

      # TODO: Refactor these execs into a popen
      alternate_vendor_name = nil
      for key, value in options
        if match = key.match(/^<([^>]+)>(.*)/)
          vendor, attr = match[1,2]
          begin
            execute "scope #{record.subnet.network} set reservedoptionvalue #{record.ip} #{SUNW[attr][:code]} #{SUNW[attr][:kind]} vendor=#{alternate_vendor_name || vendor} #{value}", msg, true
          rescue Proxy::DHCP::Error => e
            alternate_vendor_name = find_or_create_vendor_name vendor, e
            execute "scope #{record.subnet.network} set reservedoptionvalue #{ip} #{SUNW[attr][:code]} #{SUNW[attr][:kind]} vendor=#{alternate_vendor_name || vendor} #{value}", msg, true
          end
        else
          execute "scope #{record.subnet.network} set reservedoptionvalue #{record.ip} #{Standard[key][:code]} #{Standard[key][:kind]} #{value}", msg, true
        end
      end

      record
    end

    # We did not find the vendor name we wish to use registered on the DHCP server so we attempt to find if there is a vendor class using an abbreviated name.
    # E.G. We failed to find Sun-Fire-V440 so check if there is a class Fire-V440
    # If this is not available then register the supplied vendor class
    # [+vendor+]    : String containing the vendor class we wish to use
    # [+exception+] : Exception detected during the previous vendor class operation
    # Returns       : String containing the abbreviated vendor class OR nil to indicate that we registered the original longer vendor class
    def find_or_create_vendor_name vendor, exception
      if exception.message =~ /Vendor class not found/
        # Try a heuristic to find an alternative vendor class
        @classes = @classes || loadVendorClasses
        short_vendor = vendor.gsub(/^sun-/i, "")
        if short_vendor != vendor and !(short_vendor = @classes.grep(/#{short_vendor}/i)).empty?
          short_vendor = short_vendor[0]
        else
          # OK. There does not appear to be a class with an abbreviated vendor name so lets try
          # and add the class and hope that it does not conflict with the same entry under another name
          installVendorClass vendor
          short_vendor = nil
        end
      else
        raise exception
      end
      short_vendor
    end
    private :find_or_create_vendor_name

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
            Proxy::DHCP::Reservation.new(subnet, ip, mac) if subnet.include? ip
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
      msg = "Queried #{record.ip} options"

      record.options = parse_options(execute(cmd, msg)).merge(:ip => record.ip, :mac => record.mac)
    end

    def installVendorClass vendor_class
      cmd = "show class"
      msg = "Queried vendor classes"
      classes = parse_classes(execute(cmd, msg))
      return if classes.include? vendor_class
      cls = "SUNW.#{vendor_class}"

      execute("add class #{vendor_class} \"Vendor class for #{vendor_class}\" \"#{cls}\" 1", "Added class #{vendor_class}")
      for option in ["root_server_ip", "root_server_hostname", "root_path_name", "install_server_ip", "install_server_name",
                     "install_path", "sysid_server_path", "jumpstart_server_path"]
        cmd = "add optiondef #{SUNW[option][:code]} #{option} #{SUNW[option][:kind]} 0 vendor=#{vendor_class}"
        execute cmd, "Added vendor option #{option}"
      end
    end

    private
    def loadVendorClasses
      cmd = "show class"
      msg = "Queried vendor classes"
      parse_classes(execute(cmd, msg))
    end

    def loadSubnets
      super
      cmd = "show scope"
      msg = "Enumerated the scopes on #{@name}"

      execute(cmd, msg).each do |line|
        # 172.29.216.0   - 255.255.254.0  -Active        -DC BRS               -
        if match = line.match(/^\s*([\d\.]+)\s*-\s*([\d\.]+)\s*-\s*(Active|Disabled)/)
          next if (managed_subnets = SETTINGS.dhcp_subnets) and !managed_subnets.include? "#{match[1]}/#{match[2]}"

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
        if response.grep /class name being used is unknown/
          logger.info "Vendor class not found"
        else
          logger.error "Netsh failed:\n" + response.join("\n")
        end
        msg.sub! /Removed/,    "remove"
        msg.sub! /Added/,      "add"
        msg.sub! /Enumerated/, "enumerate"
        msg.sub! /Queried/,    "query"
        match = ""
        msg  = "Failed to #{msg}"
        msg += "Vendor class not found" if response.grep /class name being used is unknown/
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
      options  = {}
      vendor   = ""
      response.each do |line|
        line.chomp!
        break if line.match(/^Command completed/)

        case line
          when /For vendor class \[([^\]]+)\]:/
            vendor = "<#{$1}>"
          when /OptionId : (\d+)/
            optionId = "#{vendor}#{$1}"
          when /Option Element Value = (\S+)/
            options[optionId] = $1
        end
      end
      return options
    end

    def parse_classes response
      klass   = nil
      classes = []
      response.each do |line|
        line.chomp!
        break if line.match(/^Command completed/)

        case line
          when /Class \[([^\]]+)\]:/
            klass = $1
          when /Isvendor= TRUE/
            classes << klass
        end
      end
      return classes
    end

    def vendor_options_supported?
      true
    end

  end
end
