require 'dhcp_isc/isc_file_parser'
require 'proxy/validations'

module Proxy::DHCP::ISC
  class FileParser6 < FileParser
    include Proxy::Validations

    attr_reader :subnet_block_regex

    def initialize(subnet_service)
      super subnet_service
      @subnet_block_regex = /subnet6\s+([\da-f:]+)\/(\d{1,3})#{subnet_block_body_regex}/
    end

    def parse_record_options text
      options = super text
      case text
      when /^fixed-address6\s+(\S+)/
        options[:ip] = $1
      when /^fixed-prefix6\s+(\S+)/
        options[:prefix] = $1
      # this comes from dhcpd6.conf
      when /dhcp6\.client-id\s+(\S+)/
        options[:uid] = $1
      # and this from dhcpd6.leases
      when /^client-identifier\s+(\S+)/
        options[:uid] ||= $1
      end
      options
    end

    def parse_config_for_subnets(read_config)
      res = read_config_for_subnets(read_config).map do |match|
        network, prefix, subnet_config_lines = match
        Proxy::DHCP::Ipv6.new(network, prefix, get_subnet_options(subnet_config_lines))
      end
      res || []
    end

    def get_subnet_options(subnet_config_lines)
      parse_subnet_options(subnet_config_lines) do |option, options|
        case option
        when /^option\s+dhcp6\.name-servers\s+([\da-f:]+.*)/
          options[:domain_name_servers] = get_ip_list_from_config_line($1)
        when /^range6\s+.*temporary$/
          # do nothing, we do not care about temporary range
        when /^range6\s+([\dabcdef:]+)\s+([\da-f:]+)/
          options[:range] = get_range_from_config_file([$1, $2])
        end
      end
    end

    def get_ip_list_from_config_line(match)
      line.split(',').reject { |item| item.nil? || item.empty? }.select do |item|
        soft_validate_ip item
      end
    end

    def get_range_from_config_file(ip_range)
      ip_range.all? { |item| soft_validate_ip item } ? ip_range : []
    end
  end
end
