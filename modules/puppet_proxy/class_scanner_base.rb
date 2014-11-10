require 'puppet_proxy/puppet_cache'

module Proxy::Puppet
  class ClassScannerBase
    class << self
      # scans a given directory and its sub directory for puppet classes using the parser passed to it
      # returns an array of PuppetClass objects.
      def scan_directory directory, environment
        if Proxy::Puppet::Plugin.settings.use_cache
          PuppetCache.scan_directory_with_cache(directory, environment, self)
        else
          Dir.glob("#{directory}/*/manifests/**/*.pp").map do |filename|
            scan_manifest File.read(filename), filename
          end.compact.flatten
        end
      end
    end
  end
end