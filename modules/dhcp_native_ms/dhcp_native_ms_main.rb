require 'checks'
require 'open3'
require 'dhcp_common/server'

module Proxy::DHCP::NativeMS
  # Represents Microsoft DHCP Server manipulated via the netsh command
  # executed on a Microsoft server under a service account
  class Provider < ::Proxy::DHCP::Server

    def initialize_for_testing(params)
      @name = params[:name] || @name
      @service = params[:service] || service
      @managed_subnets = params[:subnets] || @managed_subnets
      self
    end

    def initialize
      super(Proxy::DhcpPlugin.settings.server, Proxy::DhcpPlugin.settings.subnets)
    end

    def del_record subnet, record
      validate_subnet subnet
      validate_record record
      # TODO: Refactor this into the base class
      raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?

      mac = record.mac.gsub(/:/,"")
      msg = "Removed DHCP reservation for #{record.name} => #{record.ip} - #{record.mac}"
      cmd = "scope #{subnet.network} delete reservedip #{record.ip} #{mac}"

      execute(cmd, msg)
    end

    def add_record options={}
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
          begin
            execute "scope #{record.subnet.network} set reservedoptionvalue #{record.ip} #{k[:code]} #{k[:kind]} \"#{value}\"", msg, true
          rescue Proxy::DHCP::Error => e
            raise(e) unless key.to_s == "PXEClient"
          end
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
    private :find_or_create_vendor_name

    def find_subnet_dhcp_records(subnet)
      cmd = "scope #{subnet.network} show reservedip"
      msg = "Enumerated hosts on #{subnet.network}"

      to_return = []
      # Extract the data
      execute(cmd, msg).each do |line|
        #     172.29.216.6      -    00-a0-e7-21-41-00-
        if line =~ /^\s+([\w\.]+)\s+-\s+([-a-f\d]+)/
          ip  = $1
          next unless subnet.include?(ip)
          mac = $2.gsub(/-/,":").match(/^(.*?).$/)[1]
          begin
            opts = {:subnet => subnet, :ip => ip, :mac => mac}
            opts.merge!(loadRecordOptions(opts))
            logger.debug opts.inspect
            if opts.include? :hostname
              to_return << Proxy::DHCP::Reservation.new(opts.merge(:deleteable => true))
            else
              # this is not a lease, rather reservation
              # but we require option 12(hostname) to be defined for our leases
              # workaround until #1172 is resolved.
              to_return << Proxy::DHCP::Lease.new(opts)
            end
          rescue Exception => e
            logger.debug "Skipped #{line} - #{e}"
          end
        end
      end

      to_return
    end

    def load_subnet_data subnet
      super
      records = find_subnet_dhcp_records(subnet)
      records.each do |record|
        case record
          when Proxy::DHCP::Reservation
            service.add_host(record.subnet_address, record)
          when Proxy::DHCP::Lease
            service.add_lease(record.subnet_address, record)
        end
      end
    end

    def load_subnet_options subnet
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

    def find_all_subnets
      cmd = "show scope"
      msg = "Enumerated the scopes on #{@name}"

      ret_val = []
      execute(cmd, msg).each do |line|
        # 172.29.216.0   - 255.255.254.0  -Active        -DC BRS               -
        if match = line.match(/^\s*([\d\.]+)\s*-\s*([\d\.]+)\s*-\s*(Active|Disabled)/)
          next unless managed_subnet? "#{match[1]}/#{match[2]}"
          ret_val << Proxy::DHCP::Subnet.new(match[1], match[2])
        end
      end

      ret_val
    end

    def load_subnets
      super
      service.add_subnets(*find_all_subnets)
    end

    def execute cmd, msg=nil, error_only=false
      tsecs = 5
      response = nil
      interpreter = Proxy::SETTINGS.x86_64 ? 'c:\windows\sysnative\cmd.exe' : 'c:\windows\system32\cmd.exe'
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
        raise Proxy::DHCP::Error.new("Netsh did not respond within #{tsecs} seconds")
      ensure
        std_in.close  unless std_in.nil?
        std_out.close unless std_out.nil?
        std_err.close unless std_err.nil?
      end
      report msg, response, error_only
      response
    end

    def report msg, response, error_only
      if response.grep(/completed successfully/).empty?
        if response.grep /class name being used is unknown/
          logger.warn "Vendor class not found"
        else
          logger.error "Netsh failed:\n" + response.join("\n")
        end
        msg.sub! /Removed/,    "remove"
        msg.sub! /Added/,      "add"
        msg.sub! /Enumerated/, "enumerate"
        msg.sub! /Queried/,    "query"
        msg  = "Failed to #{msg}"
        msg += "Vendor class not found" if response.grep /class name being used is unknown/
        msg += ": No entry found" if !response.grep(/not a reserved client/).empty?
        match = response.grep(/used by another client/)
        msg += ": #{match}" if !match.size.empty?
        raise Proxy::DHCP::Error.new(msg)
      else
        logger.debug msg unless error_only
      end
    rescue Proxy::DHCP::Error
      raise
    rescue
      logger.error "Netsh failed:\n" + (response.is_a?(Array) ? response.join("\n") : "Response was not an array! #{response}")
      raise Proxy::DHCP::Error.new("Unknown error while processing '#{msg}'")
    end

    def parse_options response
      option_id = nil
      vendor_class = nil
      option_element_value = nil
      option_name = nil
      options  = {}

      response.each do |line|
        line.chomp!

        break if line =~ /^Command completed/

        case line
          when /For vendor class \[([^\]]+)\]:/
            # we only support a single vendor per record, and it's SUNW-based one
            vendor_class = "<#{$1}>"
            options[option_name] = option_element_value unless option_name.nil? || option_element_value.nil?
            option_id = option_name = option_element_value = nil
          when /OptionId : (\d+)/
            options[option_name] = option_element_value unless option_name.nil? || option_element_value.nil?
            option_element_value = nil
            option_id = $1.to_i
            option_name = vendor_class.nil? ? standard_option_name(option_id) : sunw_option(option_id)
          when /Option Element Value = (\S+)/
            option_element_value = $1
        end
      end

      options[option_name] = option_element_value unless option_name.nil? || option_element_value.nil?
      options[:vendor] = vendor_class unless vendor_class.nil?
      options
    end

    def standard_option_name(option_id)
      @standard_options_by_id ||= generate_standard_options_by_id
      @standard_options_by_id[option_id]
    end

    def generate_standard_options_by_id
      Standard.inject({}) { |all, current| all[current[1][:code]] = current[0]; all }
    end

    def sunw_option(option_id)
      @sunw_options_by_id ||= generate_sunw_options_by_id
      @sunw_options_by_id[option_id]
    end

    def generate_sunw_options_by_id
      SUNW.inject({}) { |all, current| all[current[1][:code]] = current[0]; all }
    end

    def parse_classes response
      klass   = nil
      classes = []
      response.each do |line|
        line.chomp!
        break if line =~ /^Command completed/

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
