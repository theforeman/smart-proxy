module Proxy::Puppet

  class PuppetClass

    class << self
      # scans a given directory and its sub directory for puppet classes
      # returns an array of PuppetClass objects.
      def scan_directory directory
        Dir.glob("#{directory}/*/manifests/**/*.pp").map do |manifest|
          scan_manifest File.read(manifest)
        end.compact.flatten
      end

      def scan_manifest manifest
        klasses = []
        manifest.each_line do |line|
          if line.match(/^\s*class\s+([\w:-]*)/)
            klasses << new($1) unless $1 == ""
          end
        end
        klasses
      end

    end

    def initialize name
      @klass = name || raise("Must provide puppet class name")
    end

    def to_s
      self.module.nil? ? name : "#{self.module}::#{name}"
    end

    # returns module name (excluding of the class name)
    def module
      klass[0..(klass.index("::")-1)] if has_module?(klass)
    end

    # returns class name (excluding of the module name)
    def name
      has_module?(klass) ? klass[(klass.index("::")+2)..-1] : klass
    end

    private
    attr_reader :klass

    def has_module?(klass)
      !!klass.index("::")
    end

  end
end

