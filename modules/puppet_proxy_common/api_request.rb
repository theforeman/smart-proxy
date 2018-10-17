require 'net/http'
require 'net/https'
require 'uri'

module Proxy::Puppet
  class ApiRequest
    attr_reader :url, :ssl_ca, :ssl_cert, :ssl_key

    def initialize(url, ssl_ca, ssl_cert, ssl_key)
      @url = url
      @ssl_ca = ssl_ca
      @ssl_cert = ssl_cert
      @ssl_key = ssl_key
    end

    def send_request(path, timeout = 60, additional_headers = {})
      uri = URI.parse(url)
      http = create_http_context(uri, timeout)

      path = [uri.path.chomp("/"), path.start_with?("/") ? path.slice(1..-1) : path].join('/')
      req = Net::HTTP::Get.new(path)
      req.add_field('Accept', 'application/json')
      additional_headers.each_key {|k| req[k] = additional_headers[k]}
      http.request(req)
    end

    def put_data(path, data, timeout = 60, additional_headers = {})
      uri = URI.parse(url)
      http = create_http_context(uri, timeout)

      path = [uri.path.chomp("/"), path.start_with?("/") ? path.slice(1..-1) : path].join('/')
      req = Net::HTTP::Put.new(path)
      req.body = data.to_json
      req.add_field('Accept', 'application/json')
      req.add_field('Content-type', 'application/json')
      additional_headers.each_key {|k| req[k] = additional_headers[k]}
      http.request(req)
    end

    def delete(path, timeout = 60, additional_headers = {})
      uri = URI.parse(url)
      http = create_http_context(uri, timeout)

      path = [uri.path.chomp("/"), path.start_with?("/") ? path.slice(1..-1) : path].join('/')
      req = Net::HTTP::Delete.new(path)
      req.add_field('Accept', 'application/json')
      additional_headers.each_key {|k| req[k] = additional_headers[k]}
      http.request(req)
    end

    def create_http_context(uri, timeout)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = timeout

      if http.use_ssl?
        if ssl_ca && !ssl_ca.to_s.empty?
          http.ca_file     = ssl_ca
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        if ssl_cert && !ssl_cert.to_s.empty? && ssl_key && !ssl_key.to_s.empty?
          http.cert = OpenSSL::X509::Certificate.new(File.read(ssl_cert))
          http.key  = OpenSSL::PKey::RSA.new(File.read(ssl_key), nil)
        end
      end
      http
    end

    def handle_response(a_response, a_msg = nil)
      return JSON.load(a_response.body) if a_response.is_a? Net::HTTPOK
      return nil if a_response.is_a? Net::HTTPNoContent
      raise ::Proxy::Error::HttpError.new(a_response.code, a_response.body, a_msg)
    end
  end
end
