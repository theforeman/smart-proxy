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

    def send_request(path)
      uri              = URI.parse(url)
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

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

      path = [uri.path.chomp("/"), path.start_with?("/") ? path.slice(1..-1) : path].join('/')
      req = Net::HTTP::Get.new(path)
      req.add_field('Accept', 'application/json')
      http.request(req)
    end

    def handle_response(a_response, a_msg = nil)
      return JSON.load(a_response.body) if a_response.is_a? Net::HTTPOK
      raise ::Proxy::Error::HttpError.new(a_response.code, a_response.body, a_msg)
    end
  end
end
