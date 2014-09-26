require 'net/http'
require 'net/https'
require 'uri'

# TODO: need settings validation on startup, otherwise we get a 500 error due to missing/wrong config settings when api is accessed

module Proxy::HttpRequest
  class ForemanRequest
    def send_request(path, body)
      uri              = URI.parse(Proxy::SETTINGS.foreman_url.to_s)
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

      path = [uri.path, path].join('/') unless uri.path.empty?
      req = Net::HTTP::Post.new(URI.join(uri.to_s, path).path)
      req.add_field('Accept', 'application/json,version=2')
      req.content_type = 'application/json'
      req.body         = body

      http.request(req)
    end
  end

  class Facts < ForemanRequest
    def post_facts(facts)
      send_request('/api/hosts/facts',facts)
    end
  end

  class Reports < ForemanRequest
    def post_report(report)
      send_request('/api/reports',report)
    end
  end
end
