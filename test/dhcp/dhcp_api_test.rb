require 'test_helper'
require 'json'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'dhcp_common/record/lease'
require 'dhcp_common/record/reservation'
require 'dhcp/dhcp'
require 'dhcp/dependency_injection'
require 'dhcp/dhcp_api'
require 'dhcp/sparc_attrs'

ENV['RACK_ENV'] = 'test'

class DhcpApiTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include SparcAttrs

  class DhcpApiTestProvider
    def load_subnets; end
    def load_subnet_data(a_subnet); end
  end

  def app
    app = Proxy::DhcpApi.new
    app.helpers.server = @server
    app
  end

  def setup
    @server = DhcpApiTestProvider.new

    @subnets = [Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0", "routers" => ["192.168.122.250"]),
                Proxy::DHCP::Subnet.new("192.168.123.0", "255.255.255.192",
                                        "routers" => ["192.168.123.1"], "domain_name_servers" => ["192.168.123.1"],
                                        "range" => ["192.168.123.2", "192.168.123.62"]),
                Proxy::DHCP::Subnet.new("192.168.124.0", "255.255.255.0",
                                        "routers" => ["192.168.124.1", "192.168.124.2"],
                                        "domain_name_servers" => ["192.168.123.1", "192.168.122.250"])
    ]

    @subnet = @subnets.first

    @reservations = [Proxy::DHCP::Reservation.new(:hostname => "test.example.com",
                                                  :ip => "192.168.122.1",
                                                  :mac => "00:11:bb:cc:dd:ee",
                                                  :subnet => @subnet),
                     Proxy::DHCP::Reservation.new(:hostname   => "ten.example.com",
                                                  :ip         => "192.168.122.10",
                                                  :mac        => "10:10:10:10:10:10",
                                                  :subnet => @subnet)]

    @leases = [Proxy::DHCP::Lease.new(:ip => "192.168.122.2",
                                      :mac => "00:aa:bb:cc:dd:ee",
                                      :starts => date_format("Sat Jul 12 10:08:29 UTC 2014"),
                                      :ends => nil,
                                      :state => "active",
                                      :subnet => @subnet),
               Proxy::DHCP::Lease.new(:ip => "192.168.122.89",
                                      :mac => "ec:f4:bb:c6:ca:fe",
                                      :starts => date_format("2014-10-16 12:59:40 UTC"),
                                      :ends => date_format("2199-01-01 00:00:01 UTC"),
                                      :state => "active",
                                      :subnet => @subnet)]
  end

  # Date formats change between Ruby versions and JSON libraries & versions
  def date_format(date)
    JSON.load([Time.parse(date)].to_json).first
  end

  def test_get_subnets
    @server.expects(:subnets).returns(@subnets)
    get "/"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    assert_equal([{"network" => "192.168.122.0", "netmask" => "255.255.255.0", "options" => {}},
                  {"network" => "192.168.123.0", "netmask" => "255.255.255.192", "options" => {}},
                  {"network" => "192.168.124.0", "netmask" => "255.255.255.0", "options" => {}}].to_set, JSON.parse(last_response.body).to_set)
  end

  def test_get_network
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:all_hosts).with(@subnet.network).returns(@reservations)
    @server.expects(:all_leases).with(@subnet.network).returns(@leases)

    get "/192.168.122.0"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"


    data = JSON.parse(last_response.body)
    expected_reservations = JSON.parse(@reservations.to_json).to_set
    expected_leases = JSON.parse(@leases.to_json).to_set

    assert_equal expected_reservations, data['reservations'].to_set
    assert_equal expected_leases, data['leases'].to_set
  end

  def test_get_network_for_non_existent_network
    @server.expects(:find_subnet).returns(nil)
    get "/192.168.122.0"

    assert_equal 404, last_response.status
  end

  def test_get_network_unused_ip
    @server.expects(:find_subnet).returns(@subnet)
    @server.expects(:unused_ip).with(@subnet, "01:02:03:04:05:06", "192.168.122.10", "192.168.122.20").returns("192.168.122.11")

    get "/192.168.122.0/unused_ip?mac=01:02:03:04:05:06&from=192.168.122.10&to=192.168.122.20"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    assert_equal({"ip"=>"192.168.122.11"}, JSON.parse(last_response.body))
  end

  def test_get_network_record
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(@reservations.first)

    get "/192.168.122.0/192.168.122.1"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = {
      "hostname" =>"test.example.com",
      "ip"       =>"192.168.122.1",
      "mac"      =>"00:11:bb:cc:dd:ee"
    }
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_network_record_for_non_existent_record
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(nil)

    get "/192.168.122.0/192.168.122.1"

    assert_equal 404, last_response.status
  end

  def test_get_network_record_by_ip
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:find_records_by_ip).with("192.168.122.0", "192.168.122.1").returns([@reservations.first])

    get "/192.168.122.0/ip/192.168.122.1"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = [{
      "hostname" =>"test.example.com",
      "ip"       =>"192.168.122.1",
      "mac"      =>"00:11:bb:cc:dd:ee",
      "subnet"   =>"192.168.122.0/255.255.255.0" # NOTE: 'subnet' attribute isn't being used by foreman, which adds a 'network' attribute instead
    }]
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_network_record_by_mac
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:find_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee").returns(@reservations.first)

    get "/192.168.122.0/mac/00:11:bb:cc:dd:ee"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = {
      "hostname" =>"test.example.com",
      "ip"       =>"192.168.122.1",
      "mac"      =>"00:11:bb:cc:dd:ee",
      "subnet"   =>"192.168.122.0/255.255.255.0" # NOTE: 'subnet' attribute isn't being used by foreman, which adds a 'network' attribute instead
    }
    assert_equal expected, JSON.parse(last_response.body)
  end

  # New record with identical duplicate contents should be a successful no-op
  def test_create_record_with_a_collision
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    params = {
        "hostname" => "test.example.com",
        "ip"       => "192.168.122.1",
        "mac"      => "00:11:bb:cc:dd:ee",
        "network"  => "192.168.122.0",
    }
    @server.expects(:add_record).raises(Proxy::DHCP::Collision)

    post "/192.168.122.0", params

    assert_equal 409, last_response.status
  end

  def test_create_duplicate_record
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    params = {
        "hostname" => "test.example.com",
        "ip"       => "192.168.122.1",
        "mac"      => "00:11:bb:cc:dd:ee",
        "network"  => "192.168.122.0",
    }
    @server.expects(:add_record).raises(Proxy::DHCP::AlreadyExists)

    post "/192.168.122.0", params

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_create_record_new
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    record = {
      "hostname" => "ten.example.com",
      "ip"       => "192.168.122.10",
      "mac"      => "10:10:10:10:10:10",
      "network"  => "192.168.122.0",
    }
    @server.expects(:add_record).with {|params| record.all? {|k_v| params[k_v[0]] == k_v[1]} }

    post "/192.168.122.0", record

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_sparc_host_creation
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:add_record).with() {|params| sparc_attrs.all? {|k_v| params[k_v[0]] == k_v[1]} }

    post '/192.168.122.0', sparc_attrs
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
  end

  def test_delete_record
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(@reservations.first)
    @server.expects(:del_record).with(@subnet, @reservations.first)

    delete "/192.168.122.0/192.168.122.1"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_delete_records_by_ip
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:del_records_by_ip).with(@subnet, "192.168.122.1")

    delete "/192.168.122.0/ip/192.168.122.1"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_delete_records_by_mac
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:del_record_by_mac).with(@subnet, "00:11:bb:cc:dd:ee")

    delete "/192.168.122.0/mac/00:11:bb:cc:dd:ee"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_delete_non_existent_record
    @server.expects(:find_subnet).with("192.168.122.0").returns(@subnet)
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(nil)

    delete "/192.168.122.0/192.168.122.1"

    assert_equal 404, last_response.status
  end
end
