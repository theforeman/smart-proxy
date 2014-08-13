include ::Proxy::Log
begin
  require "facter"
rescue LoadError
  logger.info "Facter was not found, Facts API disabled"
end

require 'facts/facts_plugin' if defined?(:Facter)
