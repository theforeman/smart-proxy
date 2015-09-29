require 'puppet_proxy/puppet'
require 'puppet_proxy/initializer'
require 'net/http'
require 'net/https'
require 'uri'

module Proxy::Puppet
  class ApiRequest
    attr_reader :url, :ssl_ca, :ssl_cert, :ssl_key

    def initialize
      certname  = Puppet[:certname]

      @url = Proxy::Puppet::Plugin.settings.puppet_url.to_s.empty? ? "https://#{Facter.value(:fqdn)}:8140" : Proxy::Puppet::Plugin.settings.puppet_url
      begin
        URI.parse(url)
      rescue URI::InvalidURIError => e
        raise ::Puppet::Error::ConfigurationError.new("Invalid puppet_url setting: #{e}")
      end

      @ssl_ca   = Proxy::Puppet::Plugin.settings.puppet_ssl_ca
      @ssl_cert = Proxy::Puppet::Plugin.settings.puppet_ssl_cert.to_s.empty? ? "/var/lib/puppet/ssl/certs/#{certname}.pem" : Proxy::Puppet::Plugin.settings.puppet_ssl_cert
      @ssl_key  = Proxy::Puppet::Plugin.settings.puppet_ssl_key.to_s.empty? ? "/var/lib/puppet/ssl/private_keys/#{certname}.pem" : Proxy::Puppet::Plugin.settings.puppet_ssl_key
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

      path = [uri.path, path].join('/') unless uri.path.empty?
      req = Net::HTTP::Get.new(URI.join(uri.to_s, path).path)
      req.add_field('Accept', 'application/json')
      http.request(req)
    end
  end

  class EnvironmentsApi < ApiRequest
    def find_environments
      response = send_request('/v2.0/environments')
      if response.is_a? Net::HTTPOK
        JSON.load(response.body)
      else
        raise ApiError.new("Failed to query Puppet find environments API (#{response.code}): #{response.body}")
      end
    end
  end

  class EnvironmentsApiv3 < ApiRequest
    def find_environments
      response = send_request('puppet/v3/environments')
      if response.is_a? Net::HTTPOK
        JSON.load(response.body)
      else
        raise ApiError.new("Failed to query Puppet find environments API (#{response.code}): #{response.body}")
      end
    end
  end
end
