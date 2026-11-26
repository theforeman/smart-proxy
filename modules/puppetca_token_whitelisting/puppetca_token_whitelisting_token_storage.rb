module ::Proxy::PuppetCa::TokenWhitelisting
  class TokenStorage
    include ::Proxy::Log
    include ::Proxy::Util

    def initialize(tokens_file)
      @tokens_file = tokens_file
      ensure_file
    end

    def read
      lock File::LOCK_SH do |file|
        unsafe_read file
      end
    end

    def write(content)
      lock do |file|
        unsafe_write file, content
      end
    end

    def add(entry)
      lock do |file|
        content = unsafe_read file
        content << entry
        unsafe_write file, content
      end
    end

    def remove(entry)
      remove_if { |data| data == entry }
    end

    def remove_if
      raise ArgumentError, 'TokenStorage#remove_if requires a block' unless block_given?

      lock do |file|
        content = unsafe_read file

        if content.reject! { |token| yield(token) }
          unsafe_write file, content
          true
        else
          false
        end
      end
    end

    private

    def ensure_file
      FileUtils.mkdir_p File.dirname(@tokens_file)

      lock do |file|
        unsafe_write file, [] if file.size.zero? # rubocop:disable Style/ZeroLengthPredicate
      end
    end

    # These helpers must only be called with a locked file handle from #lock.
    def unsafe_read(file)
      file.rewind
      YAML.safe_load(file.read, fallback: [])
    end

    def unsafe_write(file, content)
      file.rewind
      file.truncate 0
      file.write content.to_yaml
      file.flush
    end

    def lock(locking_constant = File::LOCK_EX)
      raise ArgumentError, 'TokenStorage#lock requires a block' unless block_given?

      File.open(@tokens_file, File::RDWR | File::CREAT, 0o644) do |file|
        file.flock locking_constant
        yield file
      ensure
        file&.flock File::LOCK_UN
      end
    end
  end
end
