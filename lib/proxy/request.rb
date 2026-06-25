require 'net/http'
require 'net/https'
require 'net/http/persistent'
require 'uri'
require 'cgi'

module Proxy::HttpRequest
  class ForemanRequestFactory
    def initialize(base_uri)
      @base_uri = base_uri
    end

    def query_string(input = {})
      Rack::Utils.build_nested_query(input.compact)
    end

    def create_get(path, query = {}, headers = {})
      uri = uri(path)
      uri.query = query_string(query)
      req = Net::HTTP::Get.new(uri)
      req = add_headers(req, headers)
      [uri, req]
    end

    def uri(path)
      URI.join(@base_uri.to_s, path)
    end

    def add_headers(req, headers = {})
      req.add_field('Accept', 'application/json,version=2')
      req.content_type = headers.delete("Content-Type") || 'application/json'
      headers.each do |k, v|
        req.add_field(k, v)
      end
      req
    end

    def create_post(path, body, headers = {}, query = {})
      uri = uri(path)
      uri.query = query_string(query)
      req = Net::HTTP::Post.new(uri)
      req = add_headers(req, headers)
      req.body = body
      [uri, req]
    end
  end

  class ForemanRequest
    def send_request(uri, request)
      http.request(uri, request)
    end

    def request_factory
      ForemanRequestFactory.new(uri)
    end

    def uri
      @uri ||= URI.parse(Proxy::SETTINGS.foreman_url.to_s)
    end

    def http
      @http ||= http_init
    end

    private

    def http_init
      http             = Net::HTTP::Persistent.new(name: 'foreman')
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      if uri.scheme == 'https'
        ca_file = Proxy::SETTINGS.foreman_ssl_ca || Proxy::SETTINGS.ssl_ca_file
        certificate = Proxy::SETTINGS.foreman_ssl_cert || Proxy::SETTINGS.ssl_certificate
        private_key = Proxy::SETTINGS.foreman_ssl_key || Proxy::SETTINGS.ssl_private_key

        if ca_file && !ca_file.to_s.empty?
          http.ca_file     = ca_file
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        if certificate && !certificate.to_s.empty? && private_key && !private_key.to_s.empty?
          http.cert = OpenSSL::X509::Certificate.new(File.read(certificate))
          http.key  = OpenSSL::PKey.read(File.read(private_key), nil)
        end
      end
      http
    end
  end
end
