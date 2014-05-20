require 'net/http'
require 'net/https'
require 'uri'

class SmartProxy
  class PulpClient
    def self.get(path)
      uri = URI.parse(SETTINGS.pulp_url.to_s)
      path = [uri.path, path].join('/') unless uri.path.empty?
      req = Net::HTTP::Get.new(URI.join(uri.to_s, path).path)
      req.add_field('Accept', 'application/json')
      req.content_type = 'application/json'
      response = self.http.request(req)
    end

    def self.http
      uri = URI.parse(SETTINGS.pulp_url.to_s)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      if http.use_ssl?
        if SETTINGS.foreman_ssl_ca && !SETTINGS.foreman_ssl_ca.to_s.empty?
          http.ca_file = SETTINGS.foreman_ssl_ca
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        if SETTINGS.foreman_ssl_cert && !SETTINGS.foreman_ssl_cert.to_s.empty? && SETTINGS.foreman_ssl_key && !SETTINGS.foreman_ssl_key.to_s.empty?
          http.cert = OpenSSL::X509::Certificate.new(File.read(SETTINGS.foreman_ssl_cert))
          http.key  = OpenSSL::PKey::RSA.new(File.read(SETTINGS.foreman_ssl_key), nil)
        end
      end
      http
    end
  end

  get "/pulp/status" do
    content_type :json
    begin
      result = PulpClient.get("/api/v2/status/")
      return result.body if result.is_a?(Net::HTTPSuccess)
      log_halt result.code, "Pulp server at #{SETTINGS.pulp_url} returned an error: '#{result.message}'"
    rescue Errno::ECONNREFUSED => e
      log_halt 503, "Pulp server at #{SETTINGS.pulp_url} is not responding"
    rescue SocketError => e
      log_halt 503, "Pulp server '#{URI.parse(SETTINGS.pulp_url.to_s).host}' is unknown"
    end
  end
end
