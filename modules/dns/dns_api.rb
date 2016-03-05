require 'dns_common/dns_common'
require 'ipaddr'

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

      begin
        validate_dns_name!(fqdn)

        case type
        when 'A'
          ip = IPAddr.new(value, Socket::AF_INET).to_s
          server.create_a_record(fqdn, ip)
        when 'PTR'
          validate_reverse_dns_name!(value)
          server.create_ptr_record(fqdn, value)
        else
          log_halt(400, "unrecognized 'type' parameter: #{type}")
        end
      rescue Proxy::Dns::Collision => e
        log_halt 409, e
      rescue Exception => e
        log_halt 400, e
      end
    end

    delete '/:value/?:type?' do
      name = params[:value]
      if params[:type]
        type = params[:type]
      else
        type = name =~ /\.(in-addr|ip6)\.arpa$/ ? "PTR" : "A"
      end

      begin
        validate_dns_name!(name)

        case type
        when 'A'
          server.remove_a_record(name)
        when 'PTR'
          validate_reverse_dns_name!(name)
          server.remove_ptr_record(name)
        else
          log_halt(400, "unrecognized 'type' parameter: #{type}")
        end
      rescue Proxy::Dns::NotFound => e
        log_halt 404, e
      rescue => e
        log_halt 400, e
      end
    end

    def validate_dns_name!(name)
      raise Proxy::Dns::Error.new("Invalid DNS name #{name}") unless name =~ /^([a-zA-Z0-9]([-a-zA-Z0-9]+)?\.?)+$/
    end

    def validate_reverse_dns_name!(name)
      validate_dns_name!(name)
      raise Proxy::Dns::Error.new("Invalid reverse DNS #{name}") unless name =~ /\.(in-addr|ip6)\.arpa$/
    end
  end
end
