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

  def app
    app = Proxy::DhcpApi.new
    app.helpers.server = @server
    app
  end

  def setup
    @server = Object.new

    @subnets = [Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0", "routers" => ["192.168.122.250"]),
                Proxy::DHCP::Subnet.new("192.168.123.0", "255.255.255.192",
                                        "routers" => ["192.168.123.1"], "domain_name_servers" => ["192.168.123.1"],
                                        "range" => ["192.168.123.2", "192.168.123.62"]),
                Proxy::DHCP::Subnet.new("192.168.124.0", "255.255.255.0",
                                        "routers" => ["192.168.124.1", "192.168.124.2"],
                                        "domain_name_servers" => ["192.168.123.1", "192.168.122.250"]),
    ]

    @subnet = @subnets.first

    @reservations = [Proxy::DHCP::Reservation.new("test.example.com",
                                                  "192.168.122.1",
                                                  "00:11:bb:cc:dd:ee",
                                                  @subnet,
                                                  :hostname => "test.example.com"),
                     Proxy::DHCP::Reservation.new("ten.example.com",
                                                  "192.168.122.10",
                                                  "10:10:10:10:10:10",
                                                  @subnet,
                                                  :hostname => "ten.example.com")]

    @leases = [
      Proxy::DHCP::Lease.new(nil, "192.168.122.2", "00:aa:bb:cc:dd:ee", @subnet, date_format("Sat Jul 12 10:08:29 UTC 2014"), nil, "active"),
      Proxy::DHCP::Lease.new(nil, "192.168.122.89", "ec:f4:bb:c6:ca:fe", @subnet, date_format("2014-10-16 12:59:40 UTC"), date_format("2199-01-01 00:00:01 UTC"), "active"),
      Proxy::DHCP::Lease.new(nil, "192.168.122.5", "80:00:02:08:fe:80:00:00:00:00:00:00:00:02:aa:bb:cc:dd:ee:ff", @subnet, date_format("Sat Jul 12 10:08:29 UTC 2015"), nil, "active"),
    ]
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
    @server.expects(:all_hosts).raises(::Proxy::DHCP::SubnetNotFound)
    get "/192.168.122.0"
    assert_equal 404, last_response.status
  end

  def test_get_network_unused_ip
    @server.expects(:unused_ip).with('192.168.122.0', "01:02:03:04:05:06", "192.168.122.10", "192.168.122.20").returns("192.168.122.11")
    get "/192.168.122.0/unused_ip?mac=01:02:03:04:05:06&from=192.168.122.10&to=192.168.122.20"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    assert_equal({"ip"=>"192.168.122.11"}, JSON.parse(last_response.body))
  end

  def test_get_unused_ip_for_nonexistent_network
    @server.expects(:unused_ip).with('192.168.122.0', "01:02:03:04:05:06", "192.168.122.10", "192.168.122.20").raises(::Proxy::DHCP::SubnetNotFound)
    get "/192.168.122.0/unused_ip?mac=01:02:03:04:05:06&from=192.168.122.10&to=192.168.122.20"
    assert_equal 404, last_response.status
  end

  def test_get_unused_when_not_inmplemented
    @server.expects(:unused_ip).raises(::Proxy::DHCP::NotImplemented)
    get "/192.168.122.0/unused_ip?mac=01:02:03:04:05:06&from=192.168.122.10&to=192.168.122.20"
    assert_equal 501, last_response.status
  end

  def test_get_record
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(@reservations.first)

    get "/192.168.122.0/192.168.122.1"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = {
      "hostname" =>"test.example.com",
      "ip"       =>"192.168.122.1",
      "mac"      =>"00:11:bb:cc:dd:ee",
    }
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_record_for_non_existent_record
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(nil)
    get "/192.168.122.0/192.168.122.1"
    assert_equal 404, last_response.status
  end

  def test_get_record_for_nonexistent_network
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").raises(::Proxy::DHCP::SubnetNotFound)
    get "/192.168.122.0/192.168.122.1"
    assert_equal 404, last_response.status
  end

  def test_get_reservation_record_by_ip
    @server.expects(:find_records_by_ip).with("192.168.122.0", "192.168.122.1").returns([@reservations.first])

    get "/192.168.122.0/ip/192.168.122.1"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = [{
      "deleteable" => true,
      "type"       => "reservation",
      "hostname"   => "test.example.com",
      "ip"         => "192.168.122.1",
      "mac"        => "00:11:bb:cc:dd:ee",
      "name"       => 'test.example.com',
      "subnet"     => "192.168.122.0/255.255.255.0",
    }]
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_lease_record_by_ip
    @server.expects(:find_records_by_ip).with("192.168.122.0", "192.168.122.1").returns([@leases.first])

    get "/192.168.122.0/ip/192.168.122.1"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"

    expected = [{
      "ends" => nil,
      "ip" => "192.168.122.2",
      "mac" => "00:aa:bb:cc:dd:ee",
      "name" => "lease-00aabbccddee",
      "starts" => "2014-07-12 10:08:29 UTC",
      "state" => "active",
      "subnet" => "192.168.122.0/255.255.255.0",
      "type" => "lease",
    }]
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_record_by_ip_for_nonexistent_ip
    @server.expects(:find_records_by_ip).with("192.168.122.0", "192.168.122.1").returns([])
    get "/192.168.122.0/ip/192.168.122.1"
    assert_equal 404, last_response.status
  end

  def test_get_record_by_ip_for_nonexistent_network
    @server.expects(:find_records_by_ip).with("192.168.122.0", "192.168.122.1").raises(::Proxy::DHCP::SubnetNotFound)
    get "/192.168.122.0/ip/192.168.122.1"
    assert_equal 404, last_response.status
  end

  def test_get_record_by_mac
    @server.expects(:find_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee").returns(@reservations.first)

    get "/192.168.122.0/mac/00:11:bb:cc:dd:ee"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = {
      "deleteable" => true,
      "type"       => "reservation",
      "hostname"   =>"test.example.com",
      "ip"         =>"192.168.122.1",
      "mac"        =>"00:11:bb:cc:dd:ee",
      "name"       => 'test.example.com',
      "subnet"     =>"192.168.122.0/255.255.255.0", # NOTE: 'subnet' attribute isn't being used by foreman, which adds a 'network' attribute instead
    }
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_record_by_mac_64
    @server.expects(:find_record_by_mac).with("192.168.122.0", "80:00:02:08:fe:80:00:00:00:00:00:00:00:02:aa:bb:cc:dd:ee:ff").returns(@leases.last)

    get "/192.168.122.0/mac/80:00:02:08:fe:80:00:00:00:00:00:00:00:02:aa:bb:cc:dd:ee:ff"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = {
      "ends"=>nil,
      "ip"=>"192.168.122.5",
      "mac"=>"80:00:02:08:fe:80:00:00:00:00:00:00:00:02:aa:bb:cc:dd:ee:ff",
      "name"=>"lease-80000208fe800000000000000002aabbccddeeff",
      "starts"=>"2015-07-12 10:08:29 UTC",
      "state"=>"active",
      "subnet"=>"192.168.122.0/255.255.255.0",
      "type"=>"lease",
    }
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_record_by_mac_uppercase
    @server.expects(:find_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee").returns(@reservations.first)

    get "/192.168.122.0/mac/00:11:BB:CC:DD:EE"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = {
      "deleteable" => true,
      "type"       => "reservation",
      "hostname"   =>"test.example.com",
      "ip"         =>"192.168.122.1",
      "mac"        =>"00:11:bb:cc:dd:ee",
      "name"       => 'test.example.com',
      "subnet"     =>"192.168.122.0/255.255.255.0", # NOTE: 'subnet' attribute isn't being used by foreman, which adds a 'network' attribute instead
    }
    assert_equal expected, JSON.parse(last_response.body)
  end

  def test_get_record_by_mac_for_nonexistent_mac
    @server.expects(:find_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee").returns(nil)
    get "/192.168.122.0/mac/00:11:bb:cc:dd:ee"
    assert_equal 404, last_response.status
  end

  def test_get_record_by_mac_for_nonexistent_network
    @server.expects(:find_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee").raises(::Proxy::DHCP::SubnetNotFound)
    get "/192.168.122.0/mac/00:11:bb:cc:dd:ee"
    assert_equal 404, last_response.status
  end

  # New record with identical duplicate contents should be a successful no-op
  def test_create_record_with_a_collision
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
    record = {
      "hostname" => "ten.example.com",
      "ip"       => "192.168.122.10",
      "mac"      => "10:10:10:10:10:10",
      "network"  => "192.168.122.0",
    }
    @server.expects(:add_record).with { |params| record.all? { |k_v| params[k_v[0]] == k_v[1] } }

    post "/192.168.122.0", record

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_sparc_host_creation
    @server.expects(:add_record).with() { |params| sparc_attrs.all? { |k_v| params[k_v[0]] == k_v[1] } }

    post '/192.168.122.0', sparc_attrs
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
  end

  def test_delete_record
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(@reservations.first)
    @server.expects(:del_record).with(@reservations.first).returns(nil)

    delete "/192.168.122.0/192.168.122.1"

    assert_equal 200, last_response.status
    assert_empty last_response.body
  end

  def test_delete_records_by_ip
    @server.expects(:del_records_by_ip).with("192.168.122.0", "192.168.122.1")
    delete "/192.168.122.0/ip/192.168.122.1"
    assert_equal 200, last_response.status
    assert_empty last_response.body
  end

  def test_delete_records_by_ip_for_nonexistent_subnet
    @server.expects(:del_records_by_ip).with("192.168.122.0", "192.168.122.1").raises(::Proxy::DHCP::SubnetNotFound)
    delete "/192.168.122.0/ip/192.168.122.1"
    assert_equal 200, last_response.status
    assert_empty last_response.body
  end

  def test_delete_records_by_mac
    @server.expects(:del_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee")
    delete "/192.168.122.0/mac/00:11:bb:cc:dd:ee"
    assert_equal 200, last_response.status
    assert_empty last_response.body
  end

  def test_delete_records_by_mac_uppercase
    @server.expects(:del_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee")
    delete "/192.168.122.0/mac/00:11:BB:CC:DD:EE"
    assert_equal 200, last_response.status
    assert_empty last_response.body
  end

  def test_delete_records_by_mac_for_nonexistent_subnet
    @server.expects(:del_record_by_mac).with("192.168.122.0", "00:11:bb:cc:dd:ee").raises(::Proxy::DHCP::SubnetNotFound)
    delete "/192.168.122.0/mac/00:11:bb:cc:dd:ee"
    assert_equal 200, last_response.status
    assert_empty last_response.body
  end

  def test_delete_non_existent_record
    @server.expects(:find_record).with("192.168.122.0", "192.168.122.1").returns(nil)
    delete "/192.168.122.0/192.168.122.1"
    assert_equal 404, last_response.status
  end
end
