require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'

module Proxy::HttpRequest
  class ForemanRequestFactory
    def initialize(base_uri)
      @base_uri = base_uri
      @base_uri += '/' if @base_uri[-1..-1] != '/'
    end

    def query_string(input={})
      input.map{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v)}"}.join("&")
    end

    def create_get(path, query={})
      uri = uri(path)
      req = Net::HTTP::Get.new("#{uri.path || '/'}?#{query_string(query)}")
      req = add_headers(req)
      req
    end

    def uri(path)
      URI.join(@base_uri.to_s, path)
    end

    def add_headers(req)
      req.add_field('Accept', 'application/json,version=2')
      req.content_type = 'application/json'
      req
    end

    def create_post(path, body)
      req = Net::HTTP::Post.new(uri(path).path)
      req = add_headers(req)
      req.body = body
      req
    end
  end

  class ForemanRequest
    def send_request(request)
      http.request(request)
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
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      if http.use_ssl?
        ca_file = Proxy::SETTINGS.foreman_ssl_ca || Proxy::SETTINGS.ssl_ca_file
        certificate = Proxy::SETTINGS.foreman_ssl_cert || Proxy::SETTINGS.ssl_certificate
        private_key = Proxy::SETTINGS.foreman_ssl_key || Proxy::SETTINGS.ssl_private_key

        if ca_file && !ca_file.to_s.empty?
          http.ca_file     = ca_file
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        if certificate && !certificate.to_s.empty? && private_key && !private_key.to_s.empty?
          http.cert = OpenSSL::X509::Certificate.new(File.read(certificate))
          http.key  = OpenSSL::PKey::RSA.new(File.read(private_key), nil)
        end
      end
      return http
    end
  end

  class Facts < ForemanRequest
    def post_facts(facts)
      send_request(request_factory.create_post('api/hosts/facts', facts))
    end
  end

  class Reports < ForemanRequest
    def post_report(report)
      send_request(request_factory.create_post('api/reports', report))
    end
  end
end
