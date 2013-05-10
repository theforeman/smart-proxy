class SmartProxy
  def dns_setup(opts)
    raise "Smart Proxy is not configured to support DNS" unless SETTINGS.dns
    case SETTINGS.dns_provider
    when "nsupdate"
      require 'proxy/dns/nsupdate'
      @server = Proxy::DNS::Nsupdate.new(opts.merge(:server => SETTINGS.dns_server))
    when "nsupdate_gss"
      require 'proxy/dns/nsupdate_gss'
      @server = Proxy::DNS::NsupdateGSS.new(opts.merge(
        :server => SETTINGS.dns_server,
        :tsig_keytab => SETTINGS.dns_tsig_keytab,
        :tsig_principal => SETTINGS.dns_tsig_principal
      ))
    else
      log_halt 400, "Unrecognized or missing DNS provider: #{SETTINGS.dns_provider || "MISSING"}"
    end
  rescue => e
    log_halt 400, e
  end

  post "/dns/" do
    fqdn  = params[:fqdn]
    value = params[:value]
    type  = params[:type]
    begin
      dns_setup({:fqdn => fqdn, :value => value, :type => type})
      @server.create
    rescue Proxy::DNS::Collision => e
      log_halt 409, e
    rescue Exception => e
      log_halt 400, e
    end
  end

  delete "/dns/:value" do
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
