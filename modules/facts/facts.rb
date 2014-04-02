include ::Proxy::Log
begin
  require "facter"
  require 'facts_plugin'
rescue LoadError
  logger.info "Facter was not found, Facts API disabled"
end

