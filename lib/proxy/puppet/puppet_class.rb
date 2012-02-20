module Proxy::Puppet

  class PuppetClass
    attr_reader :name, :module

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
            klass = $1
            klasses << new(:name => puppet_class_name(klass), :module => module_name(klass))
          end
        end
        klasses
      end

      private

      # returns module name (excluding of the class name)
      # if class separator does not exists (the "::" chars), then returns the whole class name
      def module_name klass
        (i = klass.index("::")) ? klass[0..i-1] : klass
      end

      # returns class name (excluding of the module name)
      def puppet_class_name klass
        klass.gsub(module_name(klass)+"::", "")
      end
    end

    def initialize args = { }
      @name   = args[:name].to_s || raise("Must provide puppet class name")
      @module = args[:module].to_s
    end

    def to_s
      "#@module::#@name"
    end

  end
end

