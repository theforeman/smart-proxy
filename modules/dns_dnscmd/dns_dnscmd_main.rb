require 'open3'

module Proxy::Dns::Dnscmd
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util

    def initialize(a_server, a_ttl, a_rewritemap)
      super(a_server, a_ttl, a_rewritemap)
    end

    def create_a_record(fqdn, ip)
      case a_record_conflicts(fqdn, ip) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          return nil
        else
          zone = match_zone(fqdn, enum_zones)
          msg = "Added DNS entry #{fqdn} => #{ip}"
          cmd = "/RecordAdd #{zone} #{fqdn}. A #{ip}"
          execute(cmd, msg)
          nil
      end
    end

    def create_aaaa_record(fqdn, ip)
      case aaaa_record_conflicts(fqdn, ip) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          return nil
        else
          zone = match_zone(fqdn, enum_zones)
          msg = "Added DNS entry #{fqdn} => #{ip}"
          cmd = "/RecordAdd #{zone} #{fqdn}. AAAA #{ip}"
          execute(cmd, msg)
          nil
      end
    end

    def create_cname_record(fqdn, target)
      case cname_record_conflicts(fqdn, target) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          return nil
        else
          zone = match_zone(fqdn, enum_zones)
          msg = "Added CNAME entry #{fqdn} => #{target}"
          cmd = "/RecordAdd #{zone} #{fqdn}. CNAME #{target}"
          execute(cmd, msg)
          nil
      end
    end

    def create_ptr_record(fqdn, ptr)
      case ptr_record_conflicts(fqdn, ptr_to_ip(ptr)) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{ptr}' is already in use")
        when 0
          return nil
        else
          ptr = rewrite_ptr(ptr)
          zone = match_zone(ptr, enum_zones)
          msg = "Added PTR entry #{ptr} => #{fqdn}"
          cmd = "/RecordAdd #{zone} #{ptr}. PTR #{fqdn}."
          execute(cmd, msg)
          nil
      end
    end

    def remove_specific_record_from_zone(zone_name, node_name, record, type)
      msg = "Removed #{record} #{type} record #{node_name} from #{zone_name}"
      cmd = "/RecordDelete #{zone_name} #{node_name}. #{type} #{record} /f"
      execute(cmd, msg)
      nil
    end

    def remove_record(record, type)
      zone = match_zone(record, enum_zones)
      enum_records(zone, record, type).each do |specific_record|
        remove_specific_record_from_zone(zone, record, specific_record, type)
      end
      nil
    end

    def remove_a_record(fqdn)
      remove_record(fqdn,'A')
    end

    def remove_aaaa_record(fqdn)
      remove_record(fqdn,'AAAA')
    end

    def remove_cname_record(fqdn)
      remove_record(fqdn, 'CNAME')
    end

    def remove_ptr_record(ptr)
      remove_record(rewrite_ptr(ptr), 'PTR')
    end

    def execute cmd, msg=nil, error_only=false
      tsecs = 5
      response = nil
      interpreter = Proxy::SETTINGS.x86_64 ? 'c:\windows\sysnative\cmd.exe' : 'c:\windows\system32\cmd.exe'
      command  = interpreter + ' /c c:\Windows\System32\dnscmd.exe ' + "#{@server} #{cmd}"

      std_in = std_out = std_err = nil
      begin
        timeout(tsecs) do
          logger.debug "executing: #{command}"
          std_in, std_out, std_err  = Open3.popen3(command)
          response  = std_out.readlines
          response += std_err.readlines
        end
      rescue TimeoutError
        raise Proxy::Dns::Error.new("dnscmd did not respond within #{tsecs} seconds")
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
        logger.error "Dnscmd failed:\n" + response.join("\n")
        msg.sub! /Removed/,    "remove"
        msg.sub! /Added/,      "add"
        msg  = "Failed to #{msg}"
        raise Proxy::Dns::Error.new(msg) unless response.grep(/DNS_ERROR_NAME_DOES_NOT_EXIST/).any? && msg == "Failed to EnumRecords"
      else
        logger.debug msg unless error_only
      end
    rescue Proxy::Dns::Error
      raise
    rescue
      logger.error "Dnscmd failed:\n" + (response.is_a?(Array) ? response.join("\n") : "Response was not an array! #{response}")
      raise Proxy::Dns::Error.new("Unknown error while processing '#{msg}'")
    end

    def match_zone(record, zone_list)
      weight = 0 # sub zones might be independent from similar named parent zones; use weight for longest suffix match
      matched_zone = nil
      zone_list.each do |zone|
        zone_labels = zone.downcase.split(".").reverse
        zone_weight = zone_labels.length
        fqdn_labels = record.downcase.split(".")
        fqdn_labels.shift
        is_match = zone_labels.all? { |zone_label| zone_label == fqdn_labels.pop }
        # match only the longest zone suffix
        if is_match && zone_weight >= weight
          matched_zone = zone
          weight = zone_weight
        end
      end
      raise Proxy::Dns::NotFound.new("The DNS server has no authoritative zone for #{record}") unless matched_zone
      matched_zone
    end

    def enum_zones
      zones = []
      response = execute '/EnumZones', nil, true
      response.each do |line|
        next unless line =~  / Primary /
        zones << line.sub(/^ +/, '').sub(/ +.*$/, '').chomp("\n")
      end
      logger.debug "Enumerated authoritative dns zones: #{zones}"
      zones
    end

    def enum_records(zone_name, node_name, type)
      records = []
      response = execute "/EnumRecords #{zone_name} #{node_name}. /Type #{type}", "EnumRecords", true
      response.each do |line|
        line.chomp!
        logger.debug "Extracting record from dnscmd output '#{line}'"
        /^@?\s+\d+\s+(A|AAAA|PTR|CNAME)+\s+(?<record>\S+)/ =~ line
        if record.nil?
          logger.debug "No DNS record found in this line"
        else
          logger.debug "Found record '#{record}'"
          records << record
        end
      end
      logger.debug "Enumerated #{records.size} #{type} records for zone=#{zone_name} node=#{node_name} records=#{records}"
      records
    end
  end
end
