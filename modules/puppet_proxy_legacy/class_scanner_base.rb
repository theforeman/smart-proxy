module Proxy::PuppetLegacy
  class ClassScannerBase
    attr_reader :environments_retriever

    def initialize(environments_retriever)
      @environments_retriever = environments_retriever
    end

    # scans a given directory and its sub directory for puppet classes using the parser passed to it
    # returns an array of PuppetClass objects.
    def scan_directory(directory)
      Dir.glob("#{directory}/*/manifests/**/*.pp").map do |filename|
        # the encoding is ignored under 1.8.7.
        # For the rest of rubies this will force external encoding to be UTF-8
        # Earlier 1.9.x have US-ASCII by default for example
        f = File.open(filename, "r:UTF-8")
        scan_manifest f.read, filename
      end.compact.flatten
    end

    def classes(paths)
      paths.map {|path| scan_directory(path) }.flatten
    end

    def classes_in_environment(an_environment)
      classes(environments_retriever.get(an_environment).paths)
    end

    def class_count(environment)
      0 # Not implemented
    end
  end
end
