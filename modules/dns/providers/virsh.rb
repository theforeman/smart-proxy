require "proxy/virsh"

module Proxy::Dns
  class Virsh < Record
    include Proxy::Log
    include Proxy::Util
    include Proxy::Virsh

    def initialize options = {}
      @network = options[:virsh_network]
      raise "DNS virsh provider needs 'virsh_network' option" unless network
      super(options)
    end

    def create
      if @type == 'A'
        result = virsh_update_dns 'add-last', @fqdn, @value
        if result =~ /^Updated/
          return true
        else
          raise Proxy::Dns::Error.new("DNS update error: #{result}")
        end
      else
        logger.warn "not creating #{@type} record for #{@fqdn} (unsupported)"
      end
    end

    def remove
      if @type == 'A'
        result = virsh_update_dns 'delete', @fqdn, find_ip_for_host(@fqdn)
        if result =~ /^Updated/
          return true
        else
          raise Proxy::Dns::Error.new("DNS update error: #{result}")
        end
      else
        logger.warn "not deleting #{@type} record for #{@fqdn} (unsupported)"
      end
    end

  end
end
