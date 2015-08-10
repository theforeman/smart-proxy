require 'proxy/file_lock'

module Proxy
  class HttpDownload < Proxy::Util::CommandTask
    include Util

    def initialize(src, dst)
      @dst = dst
      wget = which("wget")
      super("#{wget} --timeout=10 --tries=3 --no-check-certificate -nv -c \"#{escape_for_shell(src.to_s)}\" -O \"#{escape_for_shell(dst.to_s)}\"")
    end

    def start
      lock = Proxy::FileLock.try_locking(@dst)
      if lock.nil?
        return false
      else
        super {  Proxy::FileLock.unlock(lock) }
      end
    end
  end
end
