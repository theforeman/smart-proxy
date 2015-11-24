require 'dns_common/dns_common'

module Proxy::Dns
  class Api < ::Sinatra::Base
    extend Proxy::Dns::DependencyInjection::Injectors
    inject_attr :dns_provider, :server

    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    post "/?" do
      fqdn = params[:fqdn]
      value = params[:value]
      type = params[:type].upcase unless params[:type].nil?

      log_halt(400, "'create' requires fqdn, value, and type parameters") if fqdn.nil? || value.nil? || type.nil?
      log_halt(400, "unrecognized 'type' parameter: #{type}") unless type == 'A' || type == 'PTR'

      begin
        server.create_a_record(fqdn, value) if type == 'A'
        server.create_ptr_record(fqdn, value) if type == 'PTR'
      rescue Proxy::Dns::Collision => e
        log_halt 409, e
      rescue Exception => e
        log_halt 400, e
      end
    end

    delete "/:value" do
      type = params[:value].match(/\.(in-addr|ip6)\.arpa$/) ? "PTR" : "A"

      begin
        server.remove_a_record(params[:value]) if type == 'A'
        server.remove_ptr_record(params[:value]) if type == 'PTR'
      rescue Proxy::Dns::NotFound => e
        log_halt 404, e
      rescue => e
        log_halt 400, e
      end
    end
  end
end
