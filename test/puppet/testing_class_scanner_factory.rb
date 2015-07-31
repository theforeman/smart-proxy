require 'puppet_proxy/class_scanner_factory'

class ::Proxy::Puppet::ClassScannerFactory
  def reset_cache; @@cached = nil; end
end
