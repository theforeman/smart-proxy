require 'open3'

module Proxy::Dns::Dnscmd
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util

    def initialize(a_server, a_ttl)
      super(a_server, a_ttl)
    end

    def do_create(name, value, type)
      zone = match_zone(name, enum_zones)
      msg = "Added #{type} entry #{name} => #{value}"
      value = "#{value}." if type == "PTR"
      execute("/RecordAdd", zone, "#{name}.", type, value, msg: msg, error_only: false)
      nil
    end

    def remove_specific_record_from_zone(zone_name, node_name, record, type)
      msg = "Removed #{record} #{type} record #{node_name} from #{zone_name}"
      execute("/RecordDelete", zone_name, "#{node_name}.", type, record, "/f", msg: msg, error_only: false)
      nil
    end

    def do_remove(name, type)
      zone = match_zone(name, enum_zones)
      enum_records(zone, name, type).each do |specific_record|
        remove_specific_record_from_zone(zone, name, specific_record, type)
      end
      nil
    end

    def execute(*args, **keyword_args)
      tsecs = 5
      response = nil
      std_in = std_out = std_err = nil
      real_cmd = ['c:\Windows\System32\dnscmd.exe', @server] + args
      begin
        timeout(tsecs) do
          logger.debug { "executing: #{real_cmd}" }
          std_in, std_out, std_err = popen3(*real_cmd)
          response = [std_out&.readlines, std_err&.readlines].flatten.compact
          response = nil if response == []
        end
      rescue Timeout::Error
        raise Proxy::Dns::Error.new("dnscmd did not respond within #{tsecs} seconds")
      ensure
        std_in&.close
        std_out&.close
        std_err&.close
      end
      report keyword_args[:msg], response, keyword_args[:error_only || false]
      response
    end

    def report(msg, response, error_only)
      if response.nil?
        logger.warn "Response from popen3 was nil."
        return
      end

      if response.grep(/completed successfully/).empty?
        logger.error "Command dnscmd failed:\n" + response.join("\n")
        msg.sub!(/Removed/, "remove")
        msg.sub!(/Added/, "add")
        msg = "Failed to #{msg}"
        raise Proxy::Dns::Error.new(msg) unless response.grep(/DNS_ERROR_NAME_DOES_NOT_EXIST/).any? && msg == "Failed to EnumRecords"
      else
        logger.debug msg unless error_only
      end
    rescue Proxy::Dns::Error
      raise
    rescue
      logger.error "Command dnscmd failed:\n" + (response.is_a?(Array) ? response.join("\n") : "Response was not an array! #{response}")
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

    private

    def popen3(*args)
      Open3.popen3(*args)
    end
  end
end
