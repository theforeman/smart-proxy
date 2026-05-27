require 'cgi'
require 'faraday'
require 'net/http'
require 'openssl'
require 'uri'

module Proxy::HttpRequest
  Request = Struct.new(:http_method, :path, :body, :headers, keyword_init: true)

  class Response
    attr_reader :body, :headers, :status

    def initialize(status:, body:, headers:)
      @status = status
      @body = body
      @headers = headers.transform_keys { |key| key.to_s.downcase }
    end

    def code
      status.to_s
    end

    def [](header)
      headers[header.to_s.downcase]
    end
  end

  class ForemanRequestFactory
    def initialize(base_uri)
      @base_uri = base_uri
    end

    def query_string(input = {})
      Rack::Utils.build_nested_query(input.compact)
    end

    def create_get(path, query = {}, headers = {})
      Request.new(http_method: :get,
                  path: request_path(path, query),
                  headers: add_headers(headers))
    end

    def uri(path)
      URI.join(@base_uri.to_s, path)
    end

    def add_headers(headers = {})
      outgoing_headers = headers.dup
      content_type = outgoing_headers.delete('Content-Type') || 'application/json'
      { 'Accept' => 'application/json,version=2', 'Content-Type' => content_type }.merge(outgoing_headers)
    end

    def create_post(path, body, headers = {}, query = {})
      Request.new(http_method: :post,
                  path: request_path(path, query),
                  body: body,
                  headers: add_headers(headers))
    end

    private

    def request_path(path, query = {})
      request_uri = uri(path)
      query = query_string(query)
      request_uri.query = query unless query.empty?
      request_uri.request_uri
    end
  end

  class ForemanRequest
    # Compatibility shim for existing callers that inspect timeout values via `http`.
    ConnectionInfo = Struct.new(:read_timeout, :open_timeout, :connection, keyword_init: true)

    def send_request(request)
      response = connection.run_request(request.http_method, request.path, request.body, request.headers)
      Response.new(status: response.status, body: response.body, headers: response.headers)
    end

    def request_factory
      ForemanRequestFactory.new(uri)
    end

    def uri
      @uri ||= URI.parse(Proxy::SETTINGS.foreman_url.to_s)
    end

    def connection
      @connection ||= build_connection
    end

    def http
      ConnectionInfo.new(read_timeout: read_timeout,
                         open_timeout: open_timeout,
                         connection: connection)
    end

    private

    def build_connection
      Faraday.new(url: uri.to_s, ssl: ssl_options, request: request_options)
    end

    def request_options
      { timeout: read_timeout, open_timeout: open_timeout }
    end

    def read_timeout
      # Preserve the historical Net::HTTP defaults when no explicit proxy setting is provided.
      return Proxy::SETTINGS.foreman_request_timeout.to_i if Proxy::SETTINGS.foreman_request_timeout.to_i > 0

      Net::HTTP.new(uri.host, uri.port).read_timeout
    end

    def open_timeout
      # Preserve the historical Net::HTTP defaults when no explicit proxy setting is provided.
      return Proxy::SETTINGS.foreman_open_timeout.to_i if Proxy::SETTINGS.foreman_open_timeout.to_i > 0

      Net::HTTP.new(uri.host, uri.port).open_timeout
    end

    def ssl_options
      options = { verify: false }
      ca_file = presence(Proxy::SETTINGS.foreman_ssl_ca || Proxy::SETTINGS.ssl_ca_file)
      certificate = presence(Proxy::SETTINGS.foreman_ssl_cert || Proxy::SETTINGS.ssl_certificate)
      private_key = presence(Proxy::SETTINGS.foreman_ssl_key || Proxy::SETTINGS.ssl_private_key)

      if ca_file
        options[:ca_file] = ca_file
        options[:verify] = true
      end

      if certificate && private_key
        options[:client_cert] = OpenSSL::X509::Certificate.new(File.read(certificate))
        options[:client_key] = OpenSSL::PKey.read(File.read(private_key), nil)
      end

      options
    end

    def presence(value)
      return nil if value.nil?

      normalized = value.to_s
      return nil if normalized.empty?

      normalized
    end
  end
end
