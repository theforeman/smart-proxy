module Proxy
  class ArchiveExtract < Proxy::Util::CommandTask
    include Util

    SHELL_COMMAND = 'isoinfo'

    def initialize(image_path, file_in_image, dst_path)
      args = [
        which(SHELL_COMMAND),
        # Print information from Rock Ridge extensions
        '-R',
        # Filename to read ISO-9660 image from
        '-i', image_path.to_s,
        # Extract specified file to stdout
        '-x', file_in_image.to_s
      ]

      super(args, nil, dst_path)
    end

    def start
      lock = Proxy::FileLock.try_locking(File.join(File.dirname(@output), ".#{File.basename(@output)}.lock"))
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
