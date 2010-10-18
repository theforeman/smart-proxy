require "proxy/dns/bind"
def setup(opts)
  @server = Proxy::DNS::Bind.new(opts)
end
post "/dns" do
  fqdn = params[:fqdn]
  value = params[:value]
  type = params[:type]
  begin
    setup({:fqdn => fqdn, :value => value, :type => type})
    halt 400 unless @server.create
  rescue Exception => e.to_s
    halt 400, e
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
    halt 400 unless @server.remove
  rescue => e
    halt 400, e.to_s
  end
end
