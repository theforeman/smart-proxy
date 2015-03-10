module Proxy::Dns
  class Api < ::Sinatra::Base
    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    def dns_setup(opts)

      factory = ::Proxy::Plugins.find_provider_factory(Proxy::Dns::Plugin.settings.dns_provider)
      @server = factory.call(opts)

    rescue => e
      log_halt 400, e
    end

    post "/?" do
      fqdn = params[:fqdn]
      value = params[:value]
      type = params[:type]
      begin
        dns_setup(:fqdn => fqdn, :value => value, :type => type)
        @server.create
      rescue Proxy::Dns::Collision => e
        log_halt 409, e
      rescue Exception => e
        log_halt 400, e
      end
    end

    delete "/:value" do
      case params[:value]
        when /\.(in-addr|ip6)\.arpa$/
          type = "PTR"
          value = params[:value]
        else
          fqdn = params[:value]
      end
      begin
        dns_setup(:fqdn => fqdn, :value => value, :type => type)
        @server.remove
      rescue Proxy::Dns::NotFound => e
        log_halt 404, e
      rescue => e
        log_halt 400, e
      end
    end
  end
end
