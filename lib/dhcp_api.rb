def dhcp_setup
  raise "Smart Proxy is not configured to support DHCP" unless SETTINGS.dhcp
  case SETTINGS.dhcp_vendor
  when "isc"
    require 'proxy/dhcp/server/isc'
    config   = File.read(SETTINGS.dhcp_config)
    leases   = File.read(SETTINGS.dhcp_leases)
    @server  = Proxy::DHCP::ISC.new({:name => "127.0.0.1", :config => config, :leases =>leases})
  else
    raise "Unsupported DHCP server #{SETTINGS.dhcp_vendor}"
  end
  @subnets = @server.subnets
rescue => e
  logger.warn "unable to process something: #{e}"
  halt 400, e.to_s
end

helpers do
  def load_subnet
    @subnet  = @server.find_subnet(params[:network])
    halt 404, "Subnet #{params[:network]} not found" unless @subnet
    @subnet
  end
end

before do
  dhcp_setup if request.path_info =~ /dhcp/
end

get "/dhcp" do
  begin
    if request.accept.include?("application/json")
      content_type :json

      halt 404 unless @subnets
      @subnets.map{|s| {:network => s.network, :netmask => s.netmask }}.to_json
    else
      haml :"dhcp/index"
    end
  rescue => e
    halt 400, e.to_s
  end
end

get "/dhcp/:network" do
  begin
    load_subnet
    haml :"dhcp/show"
  rescue => e
    halt 400, e.to_s
  end
end

get "/dhcp/:network/unused_ip" do
  begin
    load_subnet.unused_ip
  rescue => e
    halt 400, e.to_s
  end
end

get "/dhcp/:network/:record" do
  begin
    content_type :json
    record = load_subnet[params[:record]]
    halt 404, "Record #{params[:network]}/#{params[:record]} not found" unless record
    record.options.to_json
  rescue => e
    halt 400, e.to_s
  end
end

# create a new record in a network
post "/dhcp/:network" do
  begin
    content_type :json
    halt 400, "Record #{params[:network]}/#{params[:ip]} already exists" if @server.find_record(params[:ip])
    @server.addRecord({ :mac=> params[:mac], :nextserver=> params[:nextserver],
                      :hostname=>params[:name], :filename=> params[:filename],
                      :name=>params[:name], :ip=>params[:ip]})
  rescue => e
    logger.warn "Failed to process request - #{e}"
    halt 400, e.to_s
  end
end

# delete a record from a network
delete "/dhcp/:network/:record" do
  begin
    record = load_subnet[params[:record]]
    halt 404, "Record #{params[:network]}/#{params[:record]} not found" unless record
    @server.delRecord @subnet, record
  rescue Exception => e
    halt 400, e.to_s
  end
end
