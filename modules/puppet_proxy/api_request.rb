require 'puppet_proxy/puppet'
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

      path = [uri.path.end_with?("/") ? uri.path.slice(0..-2) : uri.path, path.start_with?("/") ? path.slice(1..-1) : path].join('/')
      req = Net::HTTP::Get.new(path)
      req.add_field('Accept', 'application/json')
      http.request(req)
    end

    def handle_response(a_response, a_msg)
      return JSON.load(a_response.body) if a_response.is_a? Net::HTTPOK
      raise ::Proxy::Error::HttpError.new(a_response.code, a_msg + " (#{a_response.code}): #{a_response.body}")
    end
  end

  class EnvironmentsApi < ApiRequest
    def find_environments
      handle_response(send_request('v2.0/environments'), "Failed to query Puppet find environments v2 API")
    end
  end

  class EnvironmentsApiv3 < ApiRequest
    def find_environments
      handle_response(send_request('puppet/v3/environments'), "Failed to query Puppet find environments v3 API")
    end
  end

  class ResourceTypeApiv3 < ApiRequest
    # kind (optional) can be 'class', 'node', or 'defined_type'
    def list_classes(environment, kind = nil)
      kind_filter = kind.nil? || kind.empty? ? "" : "kind=#{kind}&"
      handle_response(send_request("puppet/v3/resource_types/*?#{kind_filter}&environment=#{environment}"), "Failed to query Puppet search resource_types v3 API")
    end
  end
end
