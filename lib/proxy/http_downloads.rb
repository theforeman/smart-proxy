require 'proxy/file_lock'

module Proxy
  class HttpDownloads
    class << self
      def start_download(src, dst)
        lock =  Proxy::FileLock.try_locking(dst)
        unless lock.nil?
          HttpDownload.new(src, dst, lock)
        else
          false
        end
      end
    end
  end

  class HttpDownload < Proxy::Util::CommandTask
    include Util

    def initialize(src, dst, lock)
      super(command(src, dst)) {  Proxy::FileLock.unlock(lock) }
    end

    def command(src, dst)
      wget = which("wget")
      "#{wget} --timeout=10 --tries=3 --no-check-certificate -nv -c \"#{escape_for_shell(src.to_s)}\" -O \"#{escape_for_shell(dst.to_s)}\""
    end
  end
end
