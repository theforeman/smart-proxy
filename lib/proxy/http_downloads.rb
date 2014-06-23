module Proxy
  class HttpDownloads
    @@downloads_lock = Mutex.new
    @@downloads_in_progress = {}

    def self.start_download(src, dst)
      @@downloads_lock.synchronize {
        return false if download_in_progress?(dst)
        t = HttpDownload.new(src, dst)
        download_started!(dst, t)
        t
      }
    end

    def self.download_finished!(afile)
      @@downloads_lock.synchronize { @@downloads_in_progress.delete(afile) }
    end

    def self.downloads
      @@downloads_in_progress
    end

    private
    def self.download_in_progress?(afile)
      @@downloads_in_progress.has_key?(afile)
    end

    def self.download_started!(afile, thread)
      @@downloads_in_progress[afile] = thread
    end
  end

  class HttpDownload < Proxy::Util::CommandTask
    include Util

    def initialize(src, dst)
      super(command(src, dst)) { HttpDownloads.download_finished!(dst) }
    end

    def command(src, dst)
      wget = which("wget")
      "#{wget} --timeout=10 --tries=3 --no-check-certificate -nv -c \"#{escape_for_shell(src.to_s)}\" -O \"#{escape_for_shell(dst.to_s)}\""
    end
  end
end