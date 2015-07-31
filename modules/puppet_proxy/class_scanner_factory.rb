require 'puppet_proxy/class_scanner'
require 'puppet_proxy/class_scanner_eparser'
require 'puppet_proxy/puppet_cache'

module Proxy::Puppet
  class ClassScannerFactory
    def initialize(use_eparser)
      @use_eparser = use_eparser
    end

    def scanner
      parser = @use_eparser ? ::Proxy::Puppet::ClassScannerEParser : ::Proxy::Puppet::ClassScanner

      if Proxy::Puppet::Plugin.settings.use_cache
        @@cached ||= PuppetCache.new(parser, MemoryStore.new, MemoryStore.new)
      else
        parser
      end
    end
  end
end