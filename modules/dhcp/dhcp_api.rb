class Proxy::DhcpApi < ::Sinatra::Base
  extend Proxy::DHCP::DependencyInjection::Injectors

  helpers ::Proxy::Helpers
  authorize_with_trusted_hosts
  authorize_with_ssl_client
  use Rack::MethodOverride

  inject_attr :dhcp_provider, :server

  before do
    begin
      server.load_subnets
    rescue => e
      log_halt 400, e
    end
  end

  helpers do
    def load_subnet
      @subnet  = server.find_subnet(params[:network])
      log_halt 404, "Subnet #{params[:network]} not found" unless @subnet
      @subnet
    end

    def load_subnet_data
      server.load_subnet_data(@subnet)
    end
  end

  get "/?" do
    begin
      if request.accept? 'application/json'
        content_type :json

        log_halt 404, "No subnets found on server @{name}" unless server.subnets
        server.subnets.map{|s| {:network => s.network, :netmask => s.netmask, :options => s.options}}.to_json
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
      load_subnet_data

      if request.accept? 'application/json'
        content_type :json
        {:reservations => server.all_hosts(@subnet.network), :leases => server.all_leases(@subnet.network)}.to_json
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

      load_subnet
      load_subnet_data

      {:ip => server.unused_ip(@subnet, params[:mac], params[:from], params[:to])}.to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/:network/:record" do
    begin
      content_type :json

      load_subnet
      load_subnet_data

      record = server.find_record(@subnet.network, params[:record])
      log_halt 404, "Record #{params[:network]}/#{params[:record]} not found" unless record
      record.options.to_json
    rescue => e
      log_halt 400, e
    end
  end

  # create a new record in a network
  post "/:network" do
    begin
      load_subnet
      load_subnet_data

      content_type :json
      server.add_record(params)
    rescue Proxy::DHCP::Collision => e
      log_halt 409, e
    rescue Proxy::DHCP::AlreadyExists # rubocop:disable Lint/HandleExceptions
      # no need to do anything
    rescue => e
      log_halt 400, e
    end
  end

  # delete a record from a network
  delete "/:network/:record" do
    begin
      load_subnet
      load_subnet_data

      record = server.find_record(@subnet.network, params[:record])
      log_halt 404, "Record #{params[:network]}/#{params[:record]} not found" unless record
      server.del_record @subnet, record
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
