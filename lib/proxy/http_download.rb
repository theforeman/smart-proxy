require 'proxy/file_lock'

module Proxy
  class HttpDownload < Proxy::Util::CommandTask
    include Util
    DEFAULT_CONNECT_TIMEOUT = 10

    def initialize(src, dst, read_timeout = nil, connect_timeout = nil, dns_timeout = nil, verify_server_cert = false)
      @dst = dst
      logger.warn('Deprecated: HttpDownload read_timeout is deprecated and will be removed in 4.0') if read_timeout
      logger.warn('Deprecated: HttpDownload dns_timeout is deprecated and will be removed in 4.0') if dns_timeout
      connect_timeout ||= DEFAULT_CONNECT_TIMEOUT
      args = [which('curl')]

      # no cert verification if set
      args << "--insecure" unless verify_server_cert
      # print nothing
      args << "--silent"
      # except errors
      args << "--show-error"
      # timeout (others were supported by wget but not by curl)
      args += ["--connect-timeout", connect_timeout.to_s]
      # try several times
      args += ["--retry", "3"]
      # with a short delay
      args += ["--retry-delay", "10"]
      # but exit after one hour
      args += ["--max-time", "3600"]
      # keep last changed file attribute
      args << "--remote-time"
      # only download newer files
      args += ["--time-cond", dst.to_s]
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

    def start
      lock = Proxy::FileLock.try_locking(File.join(File.dirname(@dst), ".#{File.basename(@dst)}.lock"))
      if lock.nil?
        false
      else
        super do
          Proxy::FileLock.unlock(lock)
          File.unlink(lock)
        end
      end
    end
  end
end
