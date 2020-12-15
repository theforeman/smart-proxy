class Proxy::DhcpApi < ::Sinatra::Base
  extend Proxy::DHCP::DependencyInjection

  helpers ::Proxy::Helpers
  use Rack::MethodOverride

  inject_attr :dhcp_provider, :server

  get "/?" do
    content_type :json
    server.subnets.map { |s| {:network => s.network, :netmask => s.netmask, :options => s.options} }.to_json
  rescue => e
    log_halt 400, e
  end

  get "/:network" do
    content_type :json
    {:reservations => server.all_hosts(params[:network]), :leases => server.all_leases(params[:network])}.to_json
  rescue ::Proxy::DHCP::SubnetNotFound
    log_halt 404, "Subnet #{params[:network]} could not found"
  rescue => e
    log_halt 400, e
  end

  get "/:network/unused_ip" do
    content_type :json
    {:ip => server.unused_ip(params[:network], params[:mac], params[:from], params[:to])}.to_json
  rescue ::Proxy::DHCP::SubnetNotFound
    log_halt 404, "Subnet #{params[:network]} could not found"
  rescue ::Proxy::DHCP::NotImplemented => e
    log_halt 501, e
  rescue => e
    log_halt 400, e
  end

  # Deprecated, returns a single record
  get "/:network/:record" do
    content_type :json

    logger.warn('GET dhcp/:network/:record endpoint has been deprecated and will be removed in future versions. '\
                'Please use GET dhcp/:network/mac/:mac_address or GET dhcp/:network/ip/:ip_address instead.')

    record = server.find_record(params[:network], params[:record])
    log_halt 404, "No DHCP record for #{params[:network]}/#{params[:record]} found" unless record
    {:hostname => (record.hostname rescue record.name), :ip => record.ip, :mac => record.mac }.to_json
  rescue ::Proxy::DHCP::SubnetNotFound
    log_halt 404, "Subnet #{params[:network]} could not found"
  rescue => e
    log_halt 400, e
  end

  # returns an array of records for an ip address
  get "/:network/ip/:ip_address" do
    content_type :json

    records = server.find_records_by_ip(params[:network], params[:ip_address])
    log_halt 404, "No DHCP records for IP #{params[:network]}/#{params[:ip_address]} found" if records.empty?
    records.to_json
  rescue ::Proxy::DHCP::SubnetNotFound
    log_halt 404, "Subnet #{params[:network]} could not found"
  rescue => e
    log_halt 400, e
  end

  # returns a record for a mac address
  get "/:network/mac/:mac_address" do
    param_network = params[:network]
    param_mac = params[:mac_address].downcase unless params[:mac_address].nil?
    begin
      content_type :json
      record = server.find_record_by_mac(param_network, param_mac)
      log_halt 404, "No DHCP record for MAC #{param_network}/#{param_mac} found" unless record
      record.to_json
    rescue ::Proxy::DHCP::SubnetNotFound
      log_halt 404, "Subnet #{param_network} could not found"
    rescue => e
      log_halt 400, e
    end
  end

  # create a new record in a network
  post "/:network" do
    content_type :json
    # NOTE: sinatra overwrites params[:network] (required by add_record call) with the :network url parameter
    server.add_record(params)
  rescue Proxy::DHCP::Collision => e
    log_halt 409, e
  rescue Proxy::DHCP::AlreadyExists # rubocop:disable Lint/SuppressedException
  # no need to do anything
  rescue => e # rubocop:enable Lint/SuppressedException
    log_halt 400, e
  end

  # deprecated, delete a record from a network
  delete "/:network/:record" do
    logger.warn('DELETE dhcp/:network/:record endpoint has been deprecated and will be removed in future versions. '\
                'Please use DELETE dhcp/:network/mac/:mac_address or DELETE dhcp/:network/ip/:ip_address instead.')

    record = server.find_record(params[:network], params[:record])
    log_halt 404, "No DHCP record for #{params[:network]}/#{params[:record]} found" unless record
    server.del_record(record)
    nil
  rescue ::Proxy::DHCP::SubnetNotFound
    log_halt 404, "Subnet #{params[:network]} could not found"
  rescue Exception => e
    log_halt 400, e
  end

  # deletes all records for an ip address from a network
  delete "/:network/ip/:ip_address" do
    server.del_records_by_ip(params[:network], params[:ip_address])
    nil
  rescue ::Proxy::DHCP::SubnetNotFound # rubocop:disable Lint/SuppressedException
  # no need to do anything
  rescue Exception => e # rubocop:enable Lint/SuppressedException
    log_halt 400, e
  end

  # delete a record for a mac address from a network
  delete "/:network/mac/:mac_address" do
    server.del_record_by_mac(params[:network], params[:mac_address].nil? ? nil : params[:mac_address].downcase)
    nil
  rescue ::Proxy::DHCP::SubnetNotFound # rubocop:disable Lint/SuppressedException
  # no need to do anything
  rescue Exception => e # rubocop:enable Lint/SuppressedException
    log_halt 400, e
  end
end
