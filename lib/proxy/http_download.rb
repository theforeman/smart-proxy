require 'proxy/file_lock'
require 'net/http'
require 'openssl'
require 'uri'

module Proxy
  class HttpDownload < Proxy::Util::CommandTask
    include Util
    DEFAULT_CONNECT_TIMEOUT = 10
    DEFAULT_MAX_TIME = 3600
    MAX_PREFLIGHT_REDIRECTS = 5

    class PreflightError < StandardError
      attr_reader :status_code

      def initialize(message, status_code: 502)
        @status_code = status_code
        super(message)
      end
    end

    def initialize(src, dst, connect_timeout: DEFAULT_CONNECT_TIMEOUT, max_time: DEFAULT_MAX_TIME,
                   verify_server_cert: false, preflight: false, conditional: true)
      @preflight = [src, connect_timeout, verify_server_cert] if preflight
      @dst = dst
      args = [which('curl')]

      # no cert verification if set
      args << "--insecure" unless verify_server_cert
      # print nothing
      args << "--silent"
      # except errors
      args << "--show-error"
      # force it to set an exit code on failure
      args << "--fail"
      # timeout (others were supported by wget but not by curl)
      args += ["--connect-timeout", connect_timeout.to_s]
      # try several times
      args += ["--retry", "3"]
      # with a short delay
      args += ["--retry-delay", "10"]
      # Limit each transfer attempt; curl resets this limit when retrying.
      args += ["--max-time", max_time.to_s]
      # keep last changed file attribute
      args << "--remote-time"
      # only download newer files when the destination's source is unchanged
      args += ["--time-cond", dst.to_s] if conditional
      # print stats in the end
      args += [
        "--write-out",
        'Task done, result: %{http_code}, size downloaded: %{size_download}b, speed: %{speed_download}b/s, time: %{time_total}ms',
      ]
      # output file
      args += ["--output", dst.to_s]
      # follow redirects
      args << "--location"
      # and the url to download
      args << src.to_s

      super(args)
    end

    # curl follows redirects for the download. Follow the same HTTP(S) chain
    # here so a successful preflight describes the resource curl will request.
    def preflight_http(src, connect_timeout, verify_server_cert)
      uri = URI.parse(src.to_s)
      return unless %w[http https].include?(uri.scheme)

      (MAX_PREFLIGHT_REDIRECTS + 1).times do
        if uri.host.nil?
          raise PreflightError.new("Invalid HTTP download URL: #{uri}", status_code: 400)
        end

        response = preflight_request(uri, connect_timeout, verify_server_cert)
        return if response.is_a?(Net::HTTPSuccess)

        unless response.is_a?(Net::HTTPRedirection)
          begin
            response.value
          rescue Net::HTTPError => e
            raise PreflightError, "HTTP HEAD preflight failed for #{uri}: #{response.code} #{response.message}", cause: e
          end
        end

        location = response['location']
        if location.nil? || location.empty?
          raise PreflightError, "HTTP HEAD preflight redirect (#{response.code} #{response.message}) has no location: #{uri}"
        end

        begin
          uri = URI.join(uri.to_s, location)
        rescue URI::InvalidURIError => e
          raise PreflightError, "HTTP HEAD preflight failed for redirect from #{uri}: #{e.message}", cause: e
        end
        unless %w[http https].include?(uri.scheme)
          raise PreflightError, "HTTP HEAD preflight redirect (#{response.code} #{response.message}) uses unsupported protocol: #{uri.scheme}"
        end
      end

      raise PreflightError, "HTTP HEAD preflight exceeded #{MAX_PREFLIGHT_REDIRECTS} redirects for #{src}"
    rescue URI::InvalidURIError => e
      raise PreflightError.new("HTTP HEAD preflight failed for #{src}: #{e.message}", status_code: 400), cause: e
    rescue SocketError, SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      status_code = e.is_a?(Timeout::Error) ? 504 : 502
      raise PreflightError.new("HTTP HEAD preflight failed for #{uri || src}: #{e.message}", status_code: status_code), cause: e
    end

    def preflight_request(uri, connect_timeout, verify_server_cert)
      proxy = uri.find_proxy
      http = if proxy
               Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
             else
               Net::HTTP.new(uri.host, uri.port, nil)
             end
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = connect_timeout
      http.read_timeout = connect_timeout
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless verify_server_cert
      http.start { |connection| connection.head(uri.request_uri) }
    end

    private :preflight_http, :preflight_request

    def start
      lock = Proxy::FileLock.try_locking(File.join(File.dirname(@dst), ".#{File.basename(@dst)}.lock"))
      if lock.nil?
        false
      else
        super(before_start: method(:run_preflight)) do
          Proxy::FileLock.unlock(lock)
        ensure
          yield if block_given?
        end
      end
    end

    private

    def run_preflight
      return true unless @preflight

      preflight_http(*@preflight)
      true
    rescue StandardError => e
      logger.error "HTTP HEAD preflight failed for #{@preflight.first}: #{e.message}"
      false
    end
  end
end
