require 'checks'
require 'rubygems' if USE_GEMS
require 'win32/open3'

module Proxy::DHCP
  # Represents Microsoft DHCP Server manipulated via the netsh command
  # executed on a Microsoft server under a service account
  class NativeMS < Server

    def initialize(options = {})
      super options[:server]
      @options_cache = {}
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
      clear_cache
    end

    def addRecord options={}
      record = super(options)

      cmd = "scope #{record.subnet.network} add reservedip #{record.ip} #{record.mac.gsub(/:/,"")} #{record.name}"
      execute(cmd, "Added DHCP reservation for #{record}")

      options = record.options
      ignored_attributes = [:ip, :mac, :name, :subnet]
      options.delete_if{|k,v| ignored_attributes.include?(k.to_sym) }
      return if options.empty?  # This reservation is just for an IP and MAC

      # TODO: Refactor these execs into a popen
      alternate_vendor_name = nil
      for key, value in options
        if match = key.to_s.match(/^<([^>]+)>(.*)/)
          vendor, attr = match[1,2].map(&:to_sym)
          msg = "set value for #{key}"
          begin
            execute "scope #{record.subnet.network} set reservedoptionvalue #{record.ip} #{SUNW[attr][:code]} #{SUNW[attr][:kind]} vendor=#{alternate_vendor_name || vendor} #{value}", msg, true
          rescue Proxy::DHCP::Error => e
            alternate_vendor_name = find_or_create_vendor_name vendor.to_s, e
            retry
          end
        else
          logger.debug "key: " + key.inspect
          k = Standard[key] || Standard[key.to_sym]
          execute "scope #{record.subnet.network} set reservedoptionvalue #{record.ip} #{k[:code]} #{k[:kind]} #{value}", msg, true
        end
      end

      clear_cache
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
        classes = loadVendorClasses
        short_vendor = vendor.gsub(/^sun-/i, "")
        if short_vendor != vendor and !(short_vendor = classes.grep(/#{short_vendor}/i)).empty?
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
      cmd = "scope #{subnet.network} show client 1"
      msg = "Enumerated hosts on #{subnet.network}"

      # Extract the data
      execute(cmd, msg).each do |line|
        #192.29.205.4    - 255.255.255.128- 00-1e-68-65-55-f8   -4/23/2013 6:41:21 PM   -D-
        #192.29.205.5    - 255.255.255.128-00-1b-24-93-35-09   - NEVER EXPIRES        -U-  host.brs.company.com
        if (match = line.match(/^([\d\.]+)\s*-\s*[\d\.]+\s*- ?([-a-f\d]+)\s*-\s*([^-]+?)\s*-(\w)-\s*(.*)/))
          ip, mac, expire, kind, name  = match[1,5]
          next unless subnet.include?(ip)
          # Some mac addresses appear to be more than 6 bytes!
          mac = mac[0,17].gsub!(/-/,":")
          begin
            opts = {:subnet => subnet, :ip => ip, :mac => mac, :name => name}
            opts.merge!(loadRecordOptions(opts))
            logger.debug opts.inspect
            if kind == 'D' and expire !~ /^INACTIVE|^NEVER/
              Proxy::DHCP::Lease.new opts
            else
              Proxy::DHCP::Reservation.new opts.merge({:deleteable => true})
            end
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

    private
    def loadRecordOptions opts
      raise "unable to find subnet for #{opts[:ip]}" if opts[:subnet].nil?
      cmd = "scope #{opts[:subnet].network} Show ReservedOptionValue #{opts[:ip]}"
      msg = "Queried #{opts[:ip]} options"

      parse_options(opts[:ip])
    end

    def installVendorClass vendor_class
      cmd = "show class"
      msg = "Queried vendor classes"
      classes = parse_classes(execute(cmd, msg))
      return if classes.include? vendor_class
      cls = "SUNW.#{vendor_class}"

      execute("add class #{vendor_class} \"Vendor class for #{vendor_class}\" \"#{cls}\" 1", "Added class #{vendor_class}")
      for option in [:root_server_ip, :root_server_hostname, :root_path_name, :install_server_ip, :install_server_name,
                     :install_path, :sysid_server_path, :jumpstart_server_path]
        cmd = "add optiondef #{SUNW[option][:code]} #{option} #{SUNW[option][:kind]} 0 vendor=#{vendor_class}"
        execute cmd, "Added vendor option #{option}"
      end
    end

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

    def execute cmd, msg=nil, error_only=false, dumping=false
      tsecs = 10
      response = nil
      interpreter = SETTINGS.x86_64 ? 'c:\windows\sysnative\cmd.exe' : 'c:\windows\system32\cmd.exe'
      command  = interpreter + ' /c c:\Windows\System32\netsh.exe -c dhcp ' + "server #{name} #{cmd}"

      std_in = std_out = std_err = nil
      begin
        timeout(tsecs) do
          logger.debug "executing: #{command}"
          std_in, std_out, std_err  = Open3.popen3(command)
          response  = std_out.readlines
          response += std_err.readlines
        end
      rescue TimeoutError
        raise Proxy::DHCP::Error.new("'Netsh #{command}' did not respond within #{tsecs} seconds")
      ensure
        std_in.close  unless std_in.nil?
        std_out.close unless std_out.nil?
        std_err.close unless std_err.nil?
      end
      report msg, response, error_only unless dumping
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

    def clear_cache
      dump_file = "#{name}.dump"
      open_file_and_lock dump_file
      @file.close
      File.delete @filename
      File.delete @lockfile
    end

    def parse_options ip
      dump_file = "#{name}.dump"
      dump = nil
      if !File.exist?("#{Dir::tmpdir}/#{dump_file}") or Time.now > File.mtime("#{Dir::tmpdir}/#{dump_file}") + SETTINGS.dhcp_cache_period
        dump = execute("dump", "dummy message", false, true)
        open_file_and_lock dump_file
        @file.write dump
        @options_cache = {}
      end
      if @options_cache.empty?
        if dump.nil?
          open_file_and_lock dump_file, "r"
          dump = read_file_and_unlock
        else
          @file.close
          File.delete @lockfile
        end
        dump.each do |line|
          # Dhcp Server \\172.29.216.54 Scope 172.29.216.0 set reservedoptionvalue
          # 172.29.216.182 4 STRING vendor="Fire-V240" "/vol/s02/solgi_5.10/sol10_hw0910_sparc/Solaris_10/Tools/Boot"
          next unless match = line.match(/^Dhcp.*?set reservedoptionvalue ([\d\.]+) (\d+) (\w+) (?:vendor="([^"]+)" )?"(.*?)"/)
          options  = @options_cache[match[1]] || {}
          optionId = match[2].to_i
          options[:vendor] = "<#{match[4]}>" if match[4]
          opts = match[4] ? SUNW : Standard
          title = opts.select {|k,v| v[:code] == optionId}.flatten[0]
          logger.debug "found option #{title}"
          options[title] = match[5]
          @options_cache[match[1]] = options
        end
      end
      options = @options_cache[ip] || {}
      logger.debug options.inspect
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
      logger.debug "found the following classes: #{classes.join(", ")}"
      return classes
    end

    def vendor_options_supported?
      true
    end

  end
end
