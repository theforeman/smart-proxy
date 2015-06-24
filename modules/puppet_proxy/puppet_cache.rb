require 'proxy/memory_store'
require 'thread'

module Proxy::Puppet
  class PuppetCache
    include Proxy::Log

    attr_reader :class_scanner

    def initialize(class_scanner, classes_store, timestamps_store)
      @classes_cache = classes_store
      @timestamps = timestamps_store
      @class_scanner = class_scanner
      @mutex = Mutex.new
    end

    def scan_directory directory, environment
      logger.debug("Running scan_directory on #{environment}: #{directory}")

      @mutex.synchronize do
        tmp_classes = ::Proxy::MemoryStore.new
        tmp_timestamps = ::Proxy::MemoryStore.new

        Dir.glob("#{directory}/*").map do |path|
          puppetmodule = File.basename(path)
          Dir.glob("#{path}/manifests/**/*.pp").map do |filename|
            if @timestamps[directory, filename] && (File.mtime(filename).to_i <= @timestamps[directory, filename])
              logger.debug("Using #{puppetmodule} cached classes from #{filename}")
              tmp_classes[directory, filename] = @classes_cache[directory, filename]
              tmp_timestamps[directory, filename] = @timestamps[directory, filename]
            else
              logger.debug("Scanning #{puppetmodule} classes in #{filename}")
              tmp_classes[directory, filename] = class_scanner.scan_manifest File.read(filename), filename
              tmp_timestamps[directory, filename] = File.mtime(filename).to_i
            end
          end
        end
        @classes_cache[directory] = tmp_classes[directory]
        @timestamps[directory] = tmp_timestamps[directory]

        @classes_cache[directory] ? @classes_cache.values(directory).compact : []
      end
    end
  end
end