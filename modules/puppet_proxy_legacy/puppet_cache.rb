require 'proxy/memory_store'
require 'thread'

module Proxy::PuppetLegacy
  class PuppetCache < ClassScannerBase
    include Proxy::Log

    attr_reader :class_parser

    def initialize(environments_retriever, class_parser, classes_store = ::Proxy::MemoryStore.new, timestamps_store = ::Proxy::MemoryStore.new)
      @classes_cache = classes_store
      @timestamps = timestamps_store
      @class_parser = class_parser
      @mutex = Mutex.new
      super(environments_retriever)
    end

    def scan_directory directory
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
              f = File.open(filename, "r:UTF-8")
              tmp_classes[directory, filename] = class_parser.scan_manifest f.read, filename
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
