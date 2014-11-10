module Proxy
  module FileLock
    class << self
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
end