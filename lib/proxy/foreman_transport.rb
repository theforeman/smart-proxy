require 'concurrent/map'
require 'faraday'
require 'faraday/net_http_persistent'
require 'net/http'
require 'openssl'

module Proxy::HttpRequest
  class ForemanTransport
    TRANSPORT_RETRY_EXCEPTIONS = [
      Faraday::SSLError,
      Faraday::ConnectionFailed,
    ].freeze

    class << self
      def connection_cache
        @connection_cache ||= Concurrent::Map.new
      end

      def reset!
        @connection_cache = Concurrent::Map.new
      end

      def invalidate!(uri = nil)
        return reset! if uri.nil?

        connection_cache.delete(connection_cache_key(uri))
      end

      def connection_for(uri)
        connection_cache.compute_if_absent(connection_cache_key(uri)) { build_connection(uri) }
      end

      def run_request(uri, request)
        attempt = 0
        begin
          connection = connection_for(uri)
          connection.run_request(request.http_method, request.path, request.body, request.headers)
        rescue *TRANSPORT_RETRY_EXCEPTIONS
          raise if attempt >= 1

          invalidate!(uri)
          attempt += 1
          retry
        end
      end

      # Preserve the historical Net::HTTP defaults when no explicit proxy setting is provided.
      def read_timeout(uri)
        return Proxy::SETTINGS.foreman_request_timeout.to_i if read_timeout_configured?

        Net::HTTP.new(uri.host, uri.port).read_timeout
      end

      def open_timeout(uri)
        return Proxy::SETTINGS.foreman_open_timeout.to_i if open_timeout_configured?

        Net::HTTP.new(uri.host, uri.port).open_timeout
      end

      private

      def build_connection(uri)
        Faraday.new(url: uri.to_s, ssl: ssl_options, request: request_options(uri)) do |faraday|
          faraday.adapter :net_http_persistent
        end
      end

      def connection_cache_key(uri)
        [
          uri.to_s,
          ssl_paths.values,
          read_timeout(uri),
          open_timeout(uri),
          read_timeout_configured?,
        ].freeze
      end

      def request_options(uri)
        options = { open_timeout: open_timeout(uri) }
        options[:timeout] = read_timeout(uri) if read_timeout_configured?
        options
      end

      def ssl_options
        options = { verify: false }
        paths = ssl_paths

        if paths[:ca_file]
          options[:ca_file] = paths[:ca_file]
          options[:verify] = true
        end

        if paths[:certificate] && paths[:private_key]
          options[:client_cert] = OpenSSL::X509::Certificate.new(File.read(paths[:certificate]))
          options[:client_key] = OpenSSL::PKey.read(File.read(paths[:private_key]), nil)
        end

        options
      end

      def ssl_paths
        {
          ca_file: presence(Proxy::SETTINGS.foreman_ssl_ca || Proxy::SETTINGS.ssl_ca_file),
          certificate: presence(Proxy::SETTINGS.foreman_ssl_cert || Proxy::SETTINGS.ssl_certificate),
          private_key: presence(Proxy::SETTINGS.foreman_ssl_key || Proxy::SETTINGS.ssl_private_key),
        }
      end

      def read_timeout_configured?
        Proxy::SETTINGS.foreman_request_timeout.to_i > 0
      end

      def open_timeout_configured?
        Proxy::SETTINGS.foreman_open_timeout.to_i > 0
      end

      def presence(value)
        return nil if value.nil?

        normalized = value.to_s
        return nil if normalized.empty?

        normalized
      end
    end
  end
end
