require 'dhcp_isc/isc_file_parser'

module Proxy::DHCP::ISC
  class FileParser4 < FileParser
    attr_reader :subnet_block_regex

    def initialize(subnet_service)
      super subnet_service
      @subnet_block_regex = /subnet\s+([\d\.]+)\s+netmask\s+([\d\.]+)#{subnet_block_body_regex}/
    end

    def parse_record_options text
      options = super text
      case text
      when /^fixed-address\s+(\S+)/
          options[:ip] = $1
      when /^supersede server.next-server\s+=\s+(\S+)/
        begin
          ns = validate_ip hex2ip($1)
        rescue
          ns = $1.gsub("\"","")
        end
        options[:nextServer] = ns
      when /^supersede server.filename\s+=\s+"(\S+)"/
        options[:filename] = $1
      when "dynamic"
        options[:deleteable] = true
      #TODO: check if adding a new reservation with omshell for a free lease still
      #generates a conflict
      end
      options
    end

    def parse_config_for_subnets(read_config)
      read_config_for_subnets(read_config).map do |match|
        network, mask, subnet_config_lines = match
        Proxy::DHCP::Ipv4.new(network, mask, get_subnet_options(subnet_config_lines))
      end
    end

    def get_subnet_options(subnet_config_lines)
      parse_subnet_options(subnet_config_lines) do |option, options|
        case option
        when /^option\s+routers\s+[\d\.]+/
          options[:routers] = get_ip_list_from_config_line(option)
        when /^option\s+domain\-name\-servers\s+[\d\.]+/
          options[:domain_name_servers] = get_ip_list_from_config_line(option)
        when /^range\s+[\d\.]+\s+[\d\.]+/
          # get IP addr range used for this subnet
          options[:range] = get_range_from_config_line(option)
        end
      end
    end

    # Get all IPv4 addresses provided by the ISC DHCP config line following the pattern "my-config-option-or-directive IPv4_ADDR[, IPv4_ADDR] [...];" and return an array.
    def get_ip_list_from_config_line(option_line)
      option_line.scan(/\s*((?:(?:\d{1,3}\.){3}\d{1,3})\s*(?:,\s*(?:(?:\d{1,3}\.){3}\d{1,3})\s*)*)/).first.first.gsub(/\s/,'').split(",").reject{|value| value.nil? || value.empty? }
    end

    # Get IPv4 range provided by the ISC DHCP config line following the pattern "range IPv4_ADDR IPv4_ADDR;" and return an array.
    def get_range_from_config_line(range_line)
      range_line.scan(/\s*((?:\d{1,3}\.){3}\d{1,3})\s*((?:\d{1,3}\.){3}\d{1,3})\s*/).first
    end

    def hex2ip hex
      hex.split(":").map{|h| h.to_i(16).to_s}.join(".")
    end
  end
end
