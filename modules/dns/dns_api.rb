module Proxy::Dns
  class Api < ::Sinatra::Base
    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts

    def dns_setup(opts)
      raise "Smart Proxy is not configured to support DNS" unless Proxy::Dns::Plugin.settings.enabled
      case Proxy::Dns::Plugin.settings.dns_provider
      when "dnscmd"
        require 'dns/providers/dnscmd'
        @server = Proxy::Dns::Dnscmd.new(opts.merge(
          :server => Proxy::Dns::Plugin.settings.dns_server,
          :ttl => Proxy::Dns::Plugin.settings.dns_ttl
        ))
      when "nsupdate"
        require 'dns/providers/nsupdate'
        @server = Proxy::Dns::Nsupdate.new(opts.merge(
          :server => Proxy::Dns::Plugin.settings.dns_server,
          :ttl => Proxy::Dns::Plugin.settings.dns_ttl
        ))
      when "nsupdate_gss"
        require 'dns/providers/nsupdate_gss'
        @server = Proxy::Dns::NsupdateGSS.new(opts.merge(
          :server => Proxy::Dns::Plugin.settings.dns_server,
          :ttl => Proxy::Dns::Plugin.settings.dns_ttl,
          :tsig_keytab => Proxy::Dns::Plugin.settings.dns_tsig_keytab,
          :tsig_principal => Proxy::Dns::Plugin.settings.dns_tsig_principal
        ))
      when "virsh"
        require 'dns/providers/virsh'
        @server = Proxy::Dns::Virsh.new(opts.merge(
          :virsh_network => Proxy::SETTINGS.virsh_network
        ))
      else
        log_halt 400, "Unrecognized or missing DNS provider: #{Proxy::Dns::Plugin.settings.dns_provider || "MISSING"}"
      end
    rescue => e
      log_halt 400, e
    end

    post "/?" do
      fqdn  = params[:fqdn]
      value = params[:value]
      type  = params[:type]
      begin
        dns_setup({:fqdn => fqdn, :value => value, :type => type})
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
        dns_setup({:fqdn => fqdn, :value => value, :type => type})
        @server.remove
      rescue => e
        log_halt 400, e
      end
    end
  end
end
