require 'chef_proxy/resources/base'

module Proxy::Chef::Resources
  class Client < Base
    def initialize
      super
      @base = @connection.clients
    end

    def delete(fqdn)
       @base.delete(fqdn)
    end

    def show(fqdn)
      @base.fetch(fqdn)
    end
  end
end
