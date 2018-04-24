require 'ipaddr'

module Proxy::Dns
  class Api < ::Sinatra::Base
    extend Proxy::Dns::DependencyInjection
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
        if type == 'SRV'
          validate_srv_name!(fqdn)
        else
          validate_dns_name!(fqdn)
        end

        case type
        when 'A'
          ip = IPAddr.new(value, Socket::AF_INET).to_s
          server.create_a_record(fqdn, ip)
        when 'AAAA'
          ip = IPAddr.new(value, Socket::AF_INET6).to_s
          server.create_aaaa_record(fqdn, ip)
        when 'CNAME'
          validate_dns_name!(value)
          server.create_cname_record(fqdn, value)
        when 'PTR'
          validate_reverse_dns_name!(value)
          server.create_ptr_record(fqdn, value)
        when 'SRV'
          validate_srv_value!(value)
          server.create_srv_record(fqdn, value)
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
        if type == 'SRV'
          validate_srv_name!(name)
        else
          validate_dns_name!(name)
        end

        case type
        when 'A'
          server.remove_a_record(name)
        when 'AAAA'
          server.remove_aaaa_record(name)
        when 'CNAME'
          server.remove_cname_record(name)
        when 'PTR'
          validate_reverse_dns_name!(name)
          server.remove_ptr_record(name)
        when 'SRV'
          server.remove_srv_record(name)
        else
          log_halt(400, "unrecognized 'type' parameter: #{type}")
        end
      rescue Proxy::Dns::NotFound => e
        log_halt 404, e
      rescue => e
        log_halt 400, e
      end
    end

    def validate_srv_value!(value)
      priority,weight,port,target,nillval = value.split(' ')
      validate_dns_name!(target)
      raise Proxy::Dns::Error.new("Invalid DNS SRV value #{value}") unless priority.scan(/\D/).empty? and
        weight.scan(/\D/).empty? and
        port.scan(/\D/).empty? and
        (0..65535) === priority.to_i and
        (0..65535) === weight.to_i and
        (1..65535) === port.to_i and nillval.nil?
    end

    def validate_srv_name!(name)
      raise Proxy::Dns::Error.new("Invalid DNS srv name #{name}") unless name =~ /^([a-zA-Z0-9_]([-a-zA-Z0-9_]+)?\.?)+$/
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
