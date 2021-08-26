require 'proxy/file_lock'

module Proxy
  class HttpDownload < Proxy::Util::CommandTask
    include Util
    DEFAULT_READ_TIMEOUT = 60
    DEFAULT_CONNECT_TIMEOUT = 10
    DEFAULT_DNS_TIMEOUT = 10

    def initialize(src, dst, read_timeout = nil, connect_timeout = nil, dns_timeout = nil, verify_server_cert = false)
      @dst = dst
      wget = which("wget")
      read_timeout ||= DEFAULT_READ_TIMEOUT
      dns_timeout ||= DEFAULT_CONNECT_TIMEOUT
      connect_timeout ||= DEFAULT_DNS_TIMEOUT

      args = ["--connect-timeout=#{connect_timeout}",
              "--dns-timeout=#{dns_timeout}",
              "--read-timeout=#{read_timeout}",
              "--tries=3",
              "--timestamping", # turn on timestamping to prevent redownloads
              "--no-if-modified-since", # but use HTTP HEAD instead If-Modified-Since
              "-nv", src.to_s, "-O", dst.to_s]
      args.unshift("--no-check-certificate") unless verify_server_cert
      args.unshift(wget)
      super(args)
    end

    def start
      lock = Proxy::FileLock.try_locking(@dst)
      if lock.nil?
        false
      else
        super { Proxy::FileLock.unlock(lock) }
      end
    end
  end
end
