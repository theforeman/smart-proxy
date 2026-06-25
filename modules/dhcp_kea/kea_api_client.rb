# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Proxy
  module DHCP
    module KeaApi
      # A client for interacting with the ISC Kea DHCP server API. This class
      # encapsulates the logic for creating JSON-RPC commands, sending them via
      # HTTP, and handling the responses from the Kea server.
      class Client
        include Proxy::Log

        # Initialises a new Kea API client.
        #
        # @param url [String] The base URL of the Kea API endpoint (e.g. 'http://127.0.0.1:8000/').
        # @param username [String, nil] The username for HTTP Basic Authentication.
        # @param password [String, nil] The password for HTTP Basic Authentication.
        # @param open_timeout [Integer] Time in seconds to wait for the initial TCP connection to be established (defaults to 5).
        # @param read_timeout [Integer] Time in seconds to wait for a response from the server after the connection is made (defaults to 10).
        # @raise [ArgumentError] if the URL is blank, malformed, or not a valid HTTP/S URL.
        #
        # @example Basic Initialization
        #   client = Proxy::DHCP::KeaApi::Client.new(url: 'https://kea.example.com:8443')
        #
        # @example Initialization with Custom Timeouts
        #   client = Proxy::DHCP::KeaApi::Client.new(
        #     url: 'http://127.0.0.1:8000',
        #     username: 'myuser',
        #     password: 'mypassword',
        #     open_timeout: 2,
        #     read_timeout: 5
        #   )
        def initialize(url:, username: nil, password: nil, open_timeout: 5, read_timeout: 10)
          raise ArgumentError, 'Kea API URL cannot be nil or empty' if url.to_s.empty?

          @uri = URI.parse(url)

          raise ArgumentError, "Invalid Kea API URL: '#{url}' must be an HTTP or HTTPS URL" unless @uri.is_a?(URI::HTTP) || @uri.is_a?(URI::HTTPS)

          raise ArgumentError, "Invalid Kea API URL: '#{url}' is missing a host" unless @uri.host

          @username = username
          @password = password
          @open_timeout = open_timeout
          @read_timeout = read_timeout
          logger.info "Initializing Kea API client for URL: #{@uri} with timeouts (open: #{@open_timeout}s, read: #{@read_timeout}s)"
        end

        # Constructs and sends a command to the Kea API and handles its response.
        # This is the main public method for interacting with the Kea server.
        #
        # @param service [String] The Kea service to target (e.g. 'dhcp4').
        # @param command [String] The command to execute (e.g. 'config-get', 'reservation-add').
        # @param arguments [Hash] A hash of arguments required by the command. Defaults to an empty hash.
        # @return [Hash] The 'arguments' hash from the Kea API response on success.
        # @raise [Proxy::DHCP::Error] if the API returns an error or if there's a communication issue.
        #   This can be caused by underlying errors like `Net::ReadTimeout`, `Net::OpenTimeout`,
        #   `Errno::ECONNREFUSED`, or `JSON::ParserError`.
        #
        # @example Get the current DHCPv4 configuration
        #   client = Proxy::DHCP::KeaApi::Client.new(url: 'http://localhost:8000')
        #   config_response = client.post_command('dhcp4', 'config-get')
        #   # => {"Dhcp4"=>{"subnet4"=>[{"id"=>1, "subnet"=>"192.168.1.0/24", ...}]}}
        #
        # @example Add a DHCPv4 reservation
        #   client = Proxy::DHCP::KeaApi::Client.new(url: 'http://localhost:8000')
        #   add_response = client.post_command('dhcp4', 'reservation-add', {
        #     reservation: {
        #       'subnet-id': 1,
        #       'ip-address': '192.168.1.100',
        #       'hw-address': '00:11:22:33:44:55',
        #       hostname: 'my-new-host'
        #     }
        #   })
        #   # => {"text"=>"Reservation added successfully."}
        #
        # @see https://kea.readthedocs.io/en/latest/api.html General Kea Management API documentation.
        # @see https://kea.readthedocs.io/en/latest/api.html#ref-reservation-add For the `reservation-add` command.
        def post_command(service, command, arguments = {})
          header = { 'Content-Type' => 'application/json' }
          payload = {
            command: command,
            service: [service],
            arguments: arguments
          }

          # This guard clause satisfies strict linters by ensuring the host is not nil in the local scope.
          host = @uri.host
          raise 'Internal error: Kea API client URI is missing a host' unless host

          http = Net::HTTP.new(host, @uri.port)
          http.use_ssl = @uri.scheme == 'https'
          http.open_timeout = @open_timeout
          http.read_timeout = @read_timeout
          request = Net::HTTP::Post.new(@uri.request_uri, header)
          request.body = payload.to_json
          request.basic_auth(@username, @password.to_s) if @username

          logger.debug "Sending command to Kea: #{payload.inspect}"
          response = http.request(request)

          handle_response(response, command)
          # This rescue block catches specific, expected network and parsing errors,
          # wrapping them in a Foreman-specific error type for consistent handling.
        rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, JSON::ParserError => e
          logger.error "Failed to send command to Kea API: #{e.class.name} - #{e.message}"
          raise Proxy::DHCP::Error, "Kea API communication error: #{e.message}"
        end

        private

        # A private helper to parse the JSON response from Kea and route it based on success or failure.
        #
        # @param response [Net::HTTPResponse] The raw response object from the HTTP request.
        # @param command [String] The original command that was sent, used for context-specific handling.
        # @return [Hash] The 'arguments' hash from the response on success.
        # @raise [Proxy::DHCP::Error] if the response indicates a failure, is malformed, or is empty.
        # @raise [JSON::ParserError] if the response body is not valid JSON.
        # @private
        def handle_response(response, command)
          body = JSON.parse(response.body)
          logger.debug "Received response from Kea: #{body.inspect}"

          result = body.first if body.is_a?(Array)
          raise Proxy::DHCP::Error, 'Kea API Error: Invalid or empty response from server' unless result

          # If the response is successful, return its arguments. Otherwise, raise an error.
          if response_successful?(result, command)
            # Provide a fallback of '{}' to prevent returning nil if the 'arguments' key is missing.
            result['arguments'] || {}
          else
            error_message = result['text'] || 'Unknown error from Kea API'
            raise Proxy::DHCP::Error, "Kea API Error: #{error_message}"
          end
        end

        # A private predicate method to determine if a Kea response is successful.
        #
        # @param result [Hash] The parsed result hash from the Kea response body.
        # @param command [String] The original command sent, needed for special case handling.
        # @return [Boolean] `true` if the response is considered a success, `false` otherwise.
        #
        # @see https://kea.readthedocs.io/en/stable/api.html For documentation on Kea API result codes.
        # @private
        def response_successful?(result, command)
          result_code = result['result']
          raise Proxy::DHCP::Error, "Kea API Error: Response missing 'result' field" if result_code.nil?

          return true if result_code.zero?

          # Special case: 'lease4-get-all' is successful even with result code 3 (no leases found).
          command == 'lease4-get-all' && result_code == 3
        end
      end
    end
  end
end
