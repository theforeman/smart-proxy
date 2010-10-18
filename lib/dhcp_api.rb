require 'proxy/dhcp/server/isc'

def dhcp_setup
  config=File.read("etc/dhcpd.conf")
  leases=File.read("etc/dhcpd.leases")
  @server=Proxy::DHCP::ISC.new("127.0.0.1", config, leases)
  @subnets = @server.subnets
end

before do
  dhcp_setup if request.path_info =~ /dhcp/
end

get "/dhcp" do
  halt 404 unless @subnets
  haml :"dhcp/index"
end

get "/dhcp/.json" do
   content_type :json
   @subnets.map{|s| {:network => s.network, :netmask => s.netmask }}.to_json
end

get "/dhcp/:network" do
  raise Sinatra::NotFound unless @subnet = @server.find_subnet(params[:network])
  haml :"dhcp/show"
end

get "/dhcp/:network/unused_ip" do
  raise Sinatra::NotFound unless @subnet = @server.find_subnet(params[:network])
  @subnet.unused_ip
end

get "/dhcp/:network/:record.json" do
  content_type :json
  raise Sinatra::NotFound unless @subnet = @server.find_subnet(params[:network])
  record = @subnet[params[:record]]
  (record ? record.options : nil).to_json
end

# create a new record in a network
post "/dhcp/:network" do
  halt 404, "No Such Network" unless @subnet = @server.find_subnet(params[:network])
  halt 400, "Already Exists" if @server.find_record(params[:ip])
  @server.addRecord({ :mac=> params[:mac], :nextserver=> params[:nextserver],
                    :hostname=>params[:name], :filename=> params[:filename],
                    :name=>params[:name], :ip=>params[:ip]})
end

# delete a record from a network
delete "/dhcp/:network/:record" do
  subnet = @server.find_subnet(params[:network])
  record = @server.find_record(params[:record])
  halt 404 unless subnet and record
  begin
    @server.delRecord subnet, record
  rescue Exception => e
    halt 400, e.to_s
  end
end
