require 'net/http'
require 'net/https'
require 'uri'

# TODO: need settings validation on startup, otherwise we get a 500 error due to missing/wrong config settings when api is accessed
# TODO: shouldn't SSL settings use ssl_certificate, ssl_ca_file, and ssl_private_key as opposed to foreman_ssl_ca, foreman_ssl_cert, and foreman_ssl_key?

module Proxy::Chef
  class ForemanRequest
    def send_request(path, body)
      uri              = URI.parse(Proxy::SETTINGS.foreman_url.to_s)
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      if http.use_ssl?
        if Proxy::Chef::Plugin.settings.foreman_ssl_ca && !Proxy::Chef::Plugin.settings.foreman_ssl_ca.to_s.empty?
          http.ca_file     = Proxy::Chef::Plugin.settings.foreman_ssl_ca
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        if Proxy::Chef::Plugin.settings.foreman_ssl_cert && !Proxy::Chef::Plugin.settings.foreman_ssl_cert.to_s.empty? && Proxy::Chef::Plugin.settings.foreman_ssl_key && !Proxy::Chef::Plugin.settings.foreman_ssl_key.to_s.empty?
          http.cert = OpenSSL::X509::Certificate.new(File.read(Proxy::Chef::Plugin.settings.foreman_ssl_cert))
          http.key  = OpenSSL::PKey::RSA.new(File.read(Proxy::Chef::Plugin.settings.foreman_ssl_key), nil)
        end
      end

      path = [uri.path, path].join('/') unless uri.path.empty?
      req = Net::HTTP::Post.new(URI.join(uri.to_s, path).path)
      req.add_field('Accept', 'application/json,version=2')
      req.content_type = 'application/json'
      req.body         = body
      response         = http.request(req)
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
