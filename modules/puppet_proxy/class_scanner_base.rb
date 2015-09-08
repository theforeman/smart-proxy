require 'puppet_proxy/initializer'

module Proxy::Puppet
  class ClassScannerBase
    # scans a given directory and its sub directory for puppet classes using the parser passed to it
    # returns an array of PuppetClass objects.
    def scan_directory directory, environment
      Dir.glob("#{directory}/*/manifests/**/*.pp").map do |filename|
        scan_manifest File.read(filename), filename
      end.compact.flatten
    end
  end
end
