require 'net/http'
require 'uri'
require 'json'

module Proxy::DHCP::Kea
  class KeaApiClient
    include Proxy::Log

    attr_reader :api_url, :username, :password, :verify_ssl

    def initialize(api_url, username = nil, password = nil, verify_ssl: true)
      @api_url = api_url.chomp('/')
      @username = username
      @password = password
      @verify_ssl = verify_ssl
    end

    def send_command(service, command, arguments = {})
      payload = {
        'command' => command,
        'service' => [service],
        'arguments' => arguments,
      }

      logger.debug "Sending KEA command: #{command} to service: #{service}"
      logger.debug "Arguments: #{arguments.inspect}"

      response = http_post('/', payload)

      result = response.first

      if result['result'] != 0
        error_msg = "KEA command '#{command}' failed: #{result['text']}"
        logger.error error_msg
        raise error_msg
      end

      logger.debug "KEA command successful: #{result['text']}"
      result['arguments'] || {}
    end

    def config
      send_command('dhcp4', 'config-get')
    end

    def list_subnets
      conf = config
      conf.dig('Dhcp4', 'subnet4') || []
    end

    def add_reservation(subnet_id, ip_address, hw_address, hostname = nil, options = {})
      reservation = {
        'subnet-id' => subnet_id.to_i,
        'ip-address' => ip_address,
        'hw-address' => hw_address,
      }

      reservation['hostname'] = hostname if hostname

      if options[:next_server]
        reservation['next-server'] = options[:next_server]
      end

      if options[:boot_file_name]
        reservation['boot-file-name'] = options[:boot_file_name]
      end

      logger.info "Adding KEA reservation: #{ip_address} for #{hw_address} in subnet #{subnet_id}"
      send_command('dhcp4', 'reservation-add', reservation)
    end

    def delete_reservation_by_ip(subnet_id, ip_address)
      logger.info "Deleting KEA reservation: #{ip_address} from subnet #{subnet_id}"
      send_command('dhcp4', 'reservation-del', {
                     'subnet-id' => subnet_id.to_i,
        'ip-address' => ip_address,
                   })
    end

    def reservation_by_ip(subnet_id, ip_address)
      send_command('dhcp4', 'reservation-get', {
                     'subnet-id' => subnet_id.to_i,
        'ip-address' => ip_address,
                   })
    rescue => e
      logger.debug "Reservation not found for #{ip_address}: #{e.message}"
      nil
    end

    def list_leases
      send_command('dhcp4', 'lease4-get-all')
    end

    def lease_by_ip(ip_address)
      result = send_command('dhcp4', 'lease4-get', {
                              'ip-address' => ip_address,
                            })
      result['leases']&.first
    rescue => e
      logger.debug "Lease not found for #{ip_address}: #{e.message}"
      nil
    end

    private

    def http_post(path, payload)
      uri = URI.parse("#{@api_url}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = @verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json'})
      request.body = payload.to_json

      if @username && @password
        request.basic_auth(@username, @password)
      end

      logger.debug "HTTP POST to #{uri}"
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        error_msg = "HTTP request failed: #{response.code} #{response.message}"
        logger.error error_msg
        raise error_msg
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      error_msg = "Failed to parse KEA response: #{e.message}"
      logger.error error_msg
      raise error_msg
    end
  end
end
