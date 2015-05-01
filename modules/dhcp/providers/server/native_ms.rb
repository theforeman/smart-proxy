require 'checks'
require 'win32/open3' if RUBY_PLATFORM =~ /mingw/
require 'tempfile'
require 'dhcp/subnet'
require 'dhcp/record/reservation'
require 'dhcp/record/lease'
require 'dhcp/server'

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

      options = {"PXEClient" => ""}.merge(record.options)
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
            execute "scope #{record.subnet.network} set reservedoptionvalue #{record.ip} #{SUNW[attr][:code]} #{SUNW[attr][:kind]} vendor=#{alternate_vendor_name || vendor} \"#{value}\"", msg, true
          rescue Proxy::DHCP::Error => e
            alternate_vendor_name = find_or_create_vendor_name vendor.to_s, e
            retry
          end
        else
          logger.debug "key: " + key.inspect
          k = Standard[key] || Standard[key.to_sym]
          execute "scope #{record.subnet.network} set reservedoptionvalue #{record.ip} #{k[:code]} #{k[:kind]} \"#{value}\"", msg, true
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
        classes = loadVendorClasses
        short_vendor = vendor.gsub(/^sun-/i, "")
        if short_vendor != vendor && !(short_vendor = classes.grep(/#{short_vendor}/i)).empty?
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

    def subnet_entries(subnet)
      all_entries = {}
      # Extract the data and build a scriptfile
      cmd = "scope #{subnet.network} show reservedip"
      msg = "Enumerated hosts on #{subnet.network}"
      execute(cmd, msg).each_line do |line|
        #     172.29.216.6      -    00-a0-e7-21-41-00-
        if line =~ /^\s+([\w\.]+)\s+-\s+([-a-f\d]+)/
          ip  = $1
          next unless subnet.include?(ip)
          mac = $2.gsub(/-/,":").match(/^(.*?).$/)[1]
          opts = {:subnet => subnet, :ip => ip, :mac => mac}
          all_entries[ip] = opts
        end
      end

      all_entries
    end

    def build_netsh_script(subnet_entries)
      netsh_tmp = Tempfile.new('smartproxydhcp')
      netsh_tmp.write("dhcp server\n")
      subnet_entries.each_value do |entry|
        netsh_tmp.write("scope #{entry[:subnet].network} Show ReservedOptionValue #{entry[:ip]}\n")
      end

      netsh_tmp
    ensure
      netsh_tmp.close unless netsh_tmp.nil?
    end

    def subnet_entries_to_records(subnet_entries, netsh_results)
      subnet_entries.each do |ip, existing_options|
        query_result = netsh_results[ip] || ''
        new_options = parse_options(query_result)

        logger.debug "    query_result #{query_result.inspect}"
        logger.debug "     new_options #{new_options.inspect}"
        logger.debug "existing_options #{existing_options.inspect}"

        complete_subnet_entry = existing_options.merge(new_options)
        logger.debug "merged_options #{complete_subnet_entry.inspect}"
        if complete_subnet_entry.include? :hostname
          logger.info "New reservation #{complete_subnet_entry.inspect}"
          Proxy::DHCP::Reservation.new complete_subnet_entry.merge(:deleteable => true)
        else
          # this is not a lease, rather reservation
          # but we require option 12(hostname) to be defined for our leases
          # workaround until #1172 is resolved.
          logger.info "New Lease #{complete_subnet_entry.inspect}"
          Proxy::DHCP::Lease.new complete_subnet_entry
        end
      end
    end

    def loadSubnetData subnet
      super
      all_entries = subnet_entries(subnet)
      netsh_tmp = build_netsh_script(all_entries)
      script_output = execute_with_script(netsh_tmp.path,"Running NETSH in script mode")
      subnet_entries_to_records(all_entries, parse_script_output_to_hash(script_output))
    ensure
      netsh_tmp.unlink unless netsh_tmp.nil?
    end

    def loadSubnetOptions subnet
      super subnet
      raise "invalid Subnet" unless subnet.is_a? Proxy::DHCP::Subnet
      cmd = "scope #{subnet.network} Show OptionValue"
      msg = "Queried #{subnet.network} options"

      subnet.options = parse_options(execute(cmd, msg))
    end

    def loadRecordOptions opts
      raise "unable to find subnet for #{opts[:ip]}" if opts[:subnet].nil?
      cmd = "scope #{opts[:subnet].network} Show ReservedOptionValue #{opts[:ip]}"
      msg = "Queried #{opts[:ip]} options"

      parse_options(execute(cmd, msg))
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

      execute(cmd, msg).each_line do |line|
        # 172.29.216.0   - 255.255.254.0  -Active        -DC BRS               -
        if match = line.match(/^\s*([\d\.]+)\s*-\s*([\d\.]+)\s*-\s*(Active|Disabled)/)
          next unless managed_subnet? "#{match[1]}/#{match[2]}"
          Proxy::DHCP::Subnet.new(self, match[1], match[2])
        end
      end
    end

    def execute cmd, msg=nil, error_only=false
      # netsh.exe specifies using -r for remoting
      command  = 'c:\Windows\System32\netsh.exe' + " -r #{name} -c dhcp server #{cmd}"
      execute_command(command, 5, msg, error_only)
    end

    # Invokes netsh.exe with a script file
    def execute_with_script scriptfile, msg=nil, error_only=false
      command  = 'c:\Windows\System32\netsh.exe' + " -r #{name} -f #{scriptfile}"
      execute_command(command, 30, msg, error_only)
    end

    def execute_command(command, timeout, msg, error_only)
      response = nil
      std_in = std_out = std_err = nil

      interpreter = (Proxy::SETTINGS.x86_64 ? 'c:\windows\sysnative\cmd.exe' : 'c:\windows\system32\cmd.exe') + ' /c '
      full_command = interpreter + command

      begin
        timeout(timeout) do
          logger.debug "executing: #{full_command}"
          std_in, std_out, std_err  = Open3.popen3(full_command)
          response  = std_out.readlines
          response += std_err.readlines
        end
      rescue TimeoutError
        raise Proxy::DHCP::Error.new("Netsh did not respond within #{timeout} seconds")
      ensure
        std_in.close  unless std_in.nil?
        std_out.close unless std_in.nil?
        std_err.close unless std_in.nil?
      end
      report msg, response, error_only
      response
    end

    # convert scriptfile output into a hash for fast queries
    def parse_script_output_to_hash content
      processed = {}
      queryResults = ""
      anIP = nil
      content.each do |line|
        anIP = $1 if line.match(/^Options for the Reservation Address ([\w\.]+)/)

        if line.match(/^Command completed/) && !anIP.nil?
          queryResults += line
          processed[anIP] = queryResults
          queryResults = ""
          anIP = nil
        end

        queryResults += line if !anIP.nil?
      end
      logger.debug "found #{processed.size} queries"
      processed
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
        msg  = "Failed to #{msg}"
        msg += "Vendor class not found" if response.grep /class name being used is unknown/
        msg += ": No entry found" if response.grep(/not a reserved client/).size > 0
        match = response.grep(/used by another client/)
        msg += ": #{match}" if match.size > 0
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
      response.each_line do |line|
        line.chomp!
        break if line.match(/^Command completed/)

        case line
          #TODO: this logic is broken, as the output reports only once the vendor type
          # making it impossible to detect if its a standard option or a custom one.
          when /For vendor class \[([^\]]+)\]:/
            options[:vendor] = "<#{$1}>"
          when /OptionId : (\d+)/
            optionId = $1.to_i
          when /Option Element Value = (\S+)/
            #TODO move options to a class or something
            opts = SUNW.update(Standard)
            title = opts.select {|k,v| v[:code] == optionId}.flatten[0]
            options[title] = $1 if title
        end
      end
      logger.debug options.inspect
      return options
    end

    def parse_classes response
      klass   = nil
      classes = []
      response.each_line do |line|
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
