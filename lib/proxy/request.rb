require 'cgi'
require 'uri'

require 'proxy/foreman_transport'

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

    class << self
      def reset_connection_cache!
        ForemanTransport.reset!
      end
    end

    def send_request(request)
      response = ForemanTransport.run_request(uri, request)
      Response.new(status: response.status, body: response.body, headers: response.headers)
    end

    def request_factory
      ForemanRequestFactory.new(uri)
    end

    def uri
      @uri ||= URI.parse(Proxy::SETTINGS.foreman_url.to_s)
    end

    def connection
      ForemanTransport.connection_for(uri)
    end

    def http
      ConnectionInfo.new(read_timeout: read_timeout,
                         open_timeout: open_timeout,
                         connection: connection)
    end

    private

    def read_timeout
      ForemanTransport.read_timeout(uri)
    end

    def open_timeout
      ForemanTransport.open_timeout(uri)
    end
  end
end
