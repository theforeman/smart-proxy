class Proxy::DhcpApi < ::Sinatra::Base
  extend Proxy::DHCP::DependencyInjection

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
      content_type :json
      server.subnets.map{|s| {:network => s.network, :netmask => s.netmask, :options => s.options}}.to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/:network" do
    begin
      load_subnet
      load_subnet_data

      content_type :json
      {:reservations => server.all_hosts(@subnet.network), :leases => server.all_leases(@subnet.network)}.to_json
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

  # Deprecated, returns a single record
  get "/:network/:record" do
    begin
      content_type :json

      logger.warn('GET dhcp/:network/:record endpoint has been deprecated and will be removed in future versions. '\
                  'Please use GET dhcp/:network/mac/:mac_address or GET dhcp/:network/ip/:ip_address instead.')

      load_subnet
      load_subnet_data

      record = server.find_record(@subnet.network, params[:record])
      log_halt 404, "No DHCP record for #{params[:network]}/#{params[:record]} found" unless record
      record.to_json
    rescue => e
      log_halt 400, e
    end
  end

  # returns an array of records for an ip address
  get "/:network/ip/:ip_address" do
    begin
      content_type :json

      load_subnet
      load_subnet_data

      records = server.find_records_by_ip(@subnet.network, params[:ip_address])
      log_halt 404, "No DHCP records for IP #{params[:network]}/#{params[:ip_address]} found" unless records
      records.map(&:options).to_json
    rescue => e
      log_halt 400, e
    end
  end

  # returns a record for a mac address
  get "/:network/mac/:mac_address" do
    begin
      content_type :json

      load_subnet
      load_subnet_data

      record = server.find_record_by_mac(@subnet.network, params[:mac_address])
      log_halt 404, "No DHCP record for MAC #{params[:network]}/#{params[:mac_address]} found" unless record
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
      # NOTE: sinatra overwrites params[:network] (required by add_record call) with the :network url parameter
      server.add_record(params)
    rescue Proxy::DHCP::Collision => e
      log_halt 409, e
    rescue Proxy::DHCP::AlreadyExists # rubocop:disable Lint/HandleExceptions
      # no need to do anything
    rescue => e
      log_halt 400, e
    end
  end

  # deprecated, delete a record from a network
  delete "/:network/:record" do
    begin
      load_subnet
      load_subnet_data

      logger.warn('DELETE dhcp/:network/:record endpoint has been deprecated and will be removed in future versions. '\
                  'Please use DELETE dhcp/:network/mac/:mac_address or DELETE dhcp/:network/ip/:ip_address instead.')

      record = server.find_record(@subnet.network, params[:record])
      log_halt 404, "No DHCP record for #{params[:network]}/#{params[:record]} found" unless record
      server.del_record(@subnet, record).to_json
    rescue Exception => e
      log_halt 400, e
    end
  end

  # deletes all records for an ip address from a network
  delete "/:network/ip/:ip_address" do
    begin
      load_subnet
      load_subnet_data

      server.del_records_by_ip(@subnet, params[:ip_address])
      nil
    rescue Exception => e
      log_halt 400, e
    end
  end

  # delete a record for a mac address from a network
  delete "/:network/mac/:mac_address" do
    begin
      load_subnet
      load_subnet_data

      server.del_record_by_mac(@subnet, params[:mac_address])
      nil
    rescue Exception => e
      log_halt 400, e
    end
  end
end
