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
      lock(File::LOCK_SH) { parse }
    end

    def write(content)
      lock(File::LOCK_EX) do
        unsafe_write content
      end
    end

    def unsafe_write(content)
      File.write @tokens_file, content.to_yaml
    end

    def lock(mode = File::LOCK_EX, &block)
      File.open(@tokens_file, ((mode == File::LOCK_EX) ? 'r+' : 'r')) do |f|
        f.flock mode
        yield
      ensure
        f.flock File::LOCK_UN
      end
    end

    def add(entry)
      modify { |tokens| tokens << entry }
    end

    def remove(entry)
      modify { |tokens| tokens.delete_if { |data| data == entry } }
    end

    def remove_if(&block)
      modify { |tokens| tokens.delete_if(&block) }
    end

    private

    # Read-modify-write under a single exclusive lock so concurrent writers
    # cannot overwrite each other's updates (last writer used to win).
    def modify
      lock(File::LOCK_EX) do
        unsafe_write yield(parse)
      end
    end

    # An empty file (crash mid-write) reads as "no tokens" instead of nil.
    def parse
      YAML.safe_load(File.read(@tokens_file)) || []
    end
  end
end
