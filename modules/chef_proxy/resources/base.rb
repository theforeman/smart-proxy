require 'chef-api'

module Proxy::Chef
  module Resources
    class Base
      def initialize
        @connection = ChefAPI::Connection.new(
            :endpoint => Proxy::Chef::Plugin.settings.chef_server_url,
            :client => Proxy::Chef::Plugin.settings.chef_smartproxy_clientname,
            :key => Proxy::Chef::Plugin.settings.chef_smartproxy_privatekey,
        )
        @connection.ssl_verify = Proxy::Chef::Plugin.settings.chef_ssl_verify
        self_signed = Proxy::Chef::Plugin.settings.chef_ssl_pem_file
        if !self_signed.nil? && !self_signed.empty?
          @connection.ssl_pem_file = self_signed
        end
      end
    end
  end
end
