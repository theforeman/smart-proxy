class Proxy::DhcpApi < ::Sinatra::Base
  helpers ::Proxy::Helpers
  authorize_with_trusted_hosts
  use Rack::MethodOverride

  before do
    begin
      raise "Smart Proxy is not configured to support DHCP" unless Proxy::DhcpPlugin.settings.enabled
      case Proxy::DhcpPlugin.settings.dhcp_vendor.downcase
      when "isc"
        require 'dhcp/providers/server/isc'
        unless Proxy::DhcpPlugin.settings.dhcp_config and Proxy::DhcpPlugin.settings.dhcp_leases \
          and File.exist?(Proxy::DhcpPlugin.settings.dhcp_config) and File.exist?(Proxy::DhcpPlugin.settings.dhcp_leases)
          log_halt 400, "Unable to find the DHCP configuration or lease files"
        end
        @server = Proxy::DHCP::ISC.new({:name => "127.0.0.1",
                                        :config => Proxy::DhcpPlugin.settings.dhcp_config,
                                        :leases => Proxy::DhcpPlugin.settings.dhcp_leases})
      when "native_ms"
        require 'dhcp/providers/server/native_ms'
        @server = Proxy::DHCP::NativeMS.new(:server => Proxy::DhcpPlugin.settings.dhcp_server ? Proxy::DhcpPlugin.settings.dhcp_server : "127.0.0.1")
      when "virsh"
        require 'dhcp/providers/server/virsh'
        @server = Proxy::DHCP::Virsh.new(:virsh_network => Proxy::SETTINGS.virsh_network)
      else
        log_halt 400, "Unrecognized or missing DHCP vendor type: #{Proxy::DhcpPlugin.settings.dhcp_vendor.nil? ? "MISSING" : Proxy::DhcpPlugin.settings.dhcp_vendor}"
      end
      @subnets = @server.subnets
    rescue => e
      log_halt 400, e
    end
  end

  helpers do
    def load_subnet
      @subnet  = @server.find_subnet(params[:network])
      log_halt 404, "Subnet #{params[:network]} not found" unless @subnet
      @subnet
    end
  end

  get "/?" do
    begin
      if request.accept? 'application/json'
        content_type :json

        log_halt 404, "No subnets found on server @{name}" unless @subnets
        @subnets.map{|s| {:network => s.network, :netmask => s.netmask }}.to_json
      else
        erb :"dhcp/index"
      end
    rescue => e
      log_halt 400, e
    end
  end

  get "/:network" do
    begin
      load_subnet
      if request.accept? 'application/json'
        content_type :json
        {:reservations => @subnet.reservations, :leases => @subnet.leases}.to_json
      else
        erb :"dhcp/show"
      end
    rescue => e
      log_halt 400, e
    end
  end

  get "/:network/unused_ip" do
    begin
      content_type :json
      ({:ip => load_subnet.unused_ip(:from => params[:from], :to => params[:to], :mac => params[:mac])}).to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/:network/:record" do
    begin
      content_type :json
      record = load_subnet[params[:record]]
      log_halt 404, "Record #{params[:network]}/#{params[:record]} not found" unless record
      record.options.to_json
    rescue => e
      log_halt 400, e
    end
  end

  # create a new record in a network
  post "/:network" do
    begin
      content_type :json
      @server.addRecord(params)
    rescue Proxy::DHCP::Collision => e
      log_halt 409, e
    rescue Proxy::DHCP::AlreadyExists
      # no need to do anything
    rescue => e
      log_halt 400, e
    end
  end

  # delete a record from a network
  delete "/:network/:record" do
    begin
      record = load_subnet.reservation_for(params[:record])
      log_halt 404, "Record #{params[:network]}/#{params[:record]} not found" unless record
      @server.delRecord @subnet, record
      if request.accept? 'application/json'
        content_type :json
        {}
      else
        redirect "/dhcp/#{params[:network]}"
      end
    rescue Proxy::DHCP::InvalidRecord
      log_halt 404, "Record #{params[:network]}/#{params[:record]} not found"
    rescue Exception => e
      log_halt 400, e
    end
  end
end
