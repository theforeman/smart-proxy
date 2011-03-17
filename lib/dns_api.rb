require "proxy/dns/bind"

class SmartProxy
  def setup(opts)
    @server = Proxy::DNS::Bind.new(opts.merge(:server => SETTINGS.dns_server))
  end

  post "/dns/" do
    fqdn  = params[:fqdn]
    value = params[:value]
    type  = params[:type]
    begin
      setup({:fqdn => fqdn, :value => value, :type => type})
      @server.create
    rescue Exception => e
      log_halt 400, e.to_s
    end
  end

  delete "/dns/:value" do
    case params[:value]
    when /.in-addr.arpa$/
      type = "PTR"
      value = params[:value]
    else
      fqdn = params[:value]
    end
    begin
      setup({:fqdn => fqdn, :value => value, :type => type})
      @server.remove
    rescue => e
      log_halt 400, e.to_s
    end
  end
end
