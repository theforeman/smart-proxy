require 'net/http'
require 'uri'
require 'json'

module Proxy::DHCP::Kea
  class KeaApiClient
    include Proxy::Log

    RESULT_SUCCESS = 0
    RESULT_ERROR = 1
    RESULT_UNSUPPORTED = 2
    RESULT_EMPTY = 3

    PAGE_SIZE = 1000

    attr_reader :api_url, :username, :password, :verify_ssl, :timeout

    def initialize(api_url, username = nil, password = nil, verify_ssl: true, timeout: 5)
      @api_url = URI.parse(api_url)
      @username = username
      @password = password
      @verify_ssl = verify_ssl
      @timeout = timeout
    end

    def send_command(command, arguments = nil)
      payload = {'command' => command, 'service' => ['dhcp4']}
      payload['arguments'] = arguments if arguments

      logger.debug "Sending Kea command '#{command}' with arguments #{arguments.inspect}"
      result = http_post(payload).first

      case result['result']
      when RESULT_SUCCESS
        result['arguments'] || {}
      when RESULT_EMPTY
        nil
      when RESULT_UNSUPPORTED
        raise Proxy::DHCP::Error, "Kea command '#{command}' is not supported, is the required hook library loaded? #{result['text']}"
      else
        raise Proxy::DHCP::Error, "Kea command '#{command}' failed: #{result['text']}"
      end
    end

    def subnets
      config = send_command('config-get')['Dhcp4'] || {}
      shared = (config['shared-networks'] || []).flat_map { |network| network['subnet4'] || [] }
      (config['subnet4'] || []) + shared
    end

    def reservations(subnet_id)
      hosts = []
      arguments = {'subnet-id' => subnet_id, 'limit' => PAGE_SIZE}
      loop do
        page = send_command('reservation-get-page', arguments)
        break if page.nil? || page['count'].to_i.zero?
        hosts.concat(page['hosts'])
        arguments = arguments.merge(page['next'])
      end
      hosts
    end

    def reservation_by_ip(subnet_id, ip_address)
      send_command('reservation-get', 'subnet-id' => subnet_id, 'ip-address' => ip_address)
    end

    def reservation_by_mac(subnet_id, mac_address)
      send_command('reservation-get', 'subnet-id' => subnet_id, 'identifier-type' => 'hw-address', 'identifier' => mac_address)
    end

    def add_reservation(reservation)
      send_command('reservation-add', 'reservation' => reservation)
    end

    def delete_reservation(subnet_id, mac_address)
      send_command('reservation-del', 'subnet-id' => subnet_id, 'identifier-type' => 'hw-address', 'identifier' => mac_address)
    end

    def leases(subnet_id)
      result = send_command('lease4-get-all', 'subnets' => [subnet_id])
      result ? result['leases'] : []
    end

    def lease_by_ip(ip_address)
      send_command('lease4-get', 'ip-address' => ip_address)
    end

    def lease_by_mac(subnet_id, mac_address)
      send_command('lease4-get', 'subnet-id' => subnet_id, 'identifier-type' => 'hw-address', 'identifier' => mac_address)
    end

    def delete_lease(ip_address)
      send_command('lease4-del', 'ip-address' => ip_address)
    end

    private

    def http_post(payload)
      http = Net::HTTP.new(api_url.host, api_url.port)
      http.use_ssl = (api_url.scheme == 'https')
      http.verify_mode = verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = timeout
      http.read_timeout = timeout

      request = Net::HTTP::Post.new(api_url.request_uri, 'Content-Type' => 'application/json')
      request.basic_auth(username, password) if username && password
      request.body = payload.to_json

      response = http.request(request)
      raise Proxy::DHCP::Error, "Kea API request failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Proxy::DHCP::Error, "Failed to parse Kea API response: #{e.message}"
    rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise Proxy::DHCP::Error, "Unable to connect to Kea API at #{api_url}: #{e.message}"
    end
  end
end
