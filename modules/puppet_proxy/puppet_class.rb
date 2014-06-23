require 'puppet_proxy/class_scanner'
require 'puppet_proxy/class_scanner_eparser'

class Proxy::Puppet::PuppetClass
  class << self
    # scans a given directory and its sub directory for puppet classes
    # returns an array of PuppetClass objects.
    def scan_directory directory, eparser = false
      # Get a Puppet Parser to parse the manifest source
      Proxy::Puppet::Initializer.load

      if eparser
        Proxy::Puppet::ClassScannerEParser.scan_directory directory
      else
        Proxy::Puppet::ClassScanner.scan_directory directory
      end
    end
  end

  def initialize name, params = {}
    @klass  = name || raise("Must provide puppet class name")
    @params = params
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

  attr_reader :params

  private
  attr_reader :klass

  def has_module?(klass)
    !!klass.index("::")
  end
end
