require 'resolv'
require 'proxy/time_utils'
require 'forwardable'

# Decorator for Resolv and DNS::Resolv Ruby classes that performs
# logging into the smart proxy logger.
module Proxy
  class LoggingResolv
    include ::Proxy::Log
    include ::Proxy::TimeUtils
    extend Forwardable

    def_delegators :@resolv, :each_address, :each_name

    SLOW_DNS_QUERY_MS = 9000

    def initialize(resolv)
      @resolv = resolv
    end

    def resolver(override_nameserver = @server)
      dns_resolv(:nameserver => override_nameserver)
    end

    def getresource(name, typeclass)
      call_with_timing(:getresource, name, typeclass)
    end

    def getresources(name, typeclass)
      call_with_timing(:getresources, name, typeclass)
    end

    def getname(name)
      call_with_timing(:getname, name)
    end

    def getnames(name)
      call_with_timing(:getnames, name)
    end

    def getaddress(name)
      call_with_timing(:getaddress, name)
    end

    def getaddresses(name)
      call_with_timing(:getaddresses, name)
    end

    private

    def call_with_timing(method, *args)
      result = nil
      duration = time_spent_in_ms do
        result = @resolv.send(method, *args)
      end
      if duration < SLOW_DNS_QUERY_MS
        logger.debug "Finished DNS query #{method} for '#{args.first}' in #{duration.round(2)} ms"
      else
        logger.warn "Slow DNS query #{method} for #{args.inspect} took #{duration.round(2)} ms"
        logger.debug "Resolver used: #{@resolv.inspect}"
      end
      result
    end
  end
end
