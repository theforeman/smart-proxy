module Proxy
  class HttpDownloads
    class << self
      def start_download(src, dst)
        lock = try_locking(dst)
        unless lock.nil?
          HttpDownload.new(src, dst, lock)
          return true
        end
        false
      end

      def try_locking(afile)
        f = File.open(afile, File::RDWR|File::CREAT, 0644)
        return f if f.flock(File::LOCK_EX | File::LOCK_NB) == 0
        f.close
        nil
      end

      def unlock(handle)
        handle.close
      end
    end
  end

  class HttpDownload < Proxy::Util::CommandTask
    include Util

    def initialize(src, dst, lock)
      super(command(src, dst)) { HttpDownloads.unlock(lock) }
    end

    def command(src, dst)
      wget = which("wget")
      "#{wget} --timeout=10 --tries=3 --no-check-certificate -nv -c \"#{escape_for_shell(src.to_s)}\" -O \"#{escape_for_shell(dst.to_s)}\""
    end
  end
end