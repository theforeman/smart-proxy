module ::Proxy::PuppetCa::TokenWhitelisting
  class TokenStorage
    include ::Proxy::Log
    include ::Proxy::Util

    def initialize(tokens_file)
      @tokens_file = tokens_file
      ensure_file
    end

    def ensure_file
      return if File.exist?(@tokens_file)
      FileUtils.mkdir_p File.dirname(@tokens_file)
      FileUtils.touch @tokens_file
      write []
    end

    def read
      YAML.safe_load File.read @tokens_file
    end

    def write(content)
      lock do
        unsafe_write content
      end
    end

    def unsafe_write(content)
      File.write @tokens_file, content.to_yaml
    end

    def lock(&block)
      File.open(@tokens_file, "r+") do |f|
        f.flock File::LOCK_EX
        yield
      ensure
        f.flock File::LOCK_UN
      end
    end

    def add(entry)
      write read.push entry
    end

    def remove(entry)
      write read.delete_if { |data| data == entry }
    end

    def remove_if(&block)
      lock do
        unsafe_write read.delete_if { |token| yield(token) }
      end
    end
  end
end
