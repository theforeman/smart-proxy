require 'test_helper'
require 'json'
require 'ostruct'

require 'dhcp/dhcp'
require 'dhcp/dhcp_api'
require 'dhcp/providers/server/isc'
require 'dhcp/sparc_attrs'

ENV['RACK_ENV'] = 'test'

class DhcpApiTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include SparcAttrs

  def app
    Proxy::DhcpApi.new
  end

  def setup
    Proxy::DhcpPlugin.load_test_settings(
      :enabled => true,
      :dhcp_vendor => 'isc',
      :dhcp_config => './test/fixtures/dhcp/dhcp.conf',
      :dhcp_leases => './test/fixtures/dhcp/dhcp.leases',
      :dhcp_subnets => '192.168.122.0/255.255.255.0')

    Proxy::DHCP::Server::ISC.any_instance.stubs(:omcmd)
  end

  # Date formats change between Ruby versions and JSON libraries & versions
  def date_format(date)
    JSON.load([Time.parse(date)].to_json).first
  end

  def test_api_01_get_root
    get "/"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    expected = [{
        "network"=>"192.168.122.0",
        "netmask"=>"255.255.255.0",
        "options"=>{"routers"=>["192.168.122.250"]}
      },{
        "network"=>"192.168.123.0",
        "netmask"=>"255.255.255.192",
        "options"=>{
          "routers"=>["192.168.123.1"],
          "domain_name_servers"=>["192.168.123.1"],
          "range"=>["192.168.123.2", "192.168.123.62"]
        }
      },{
        "network"=>"192.168.124.0",
        "netmask"=>"255.255.255.0",
        "options"=>{
          "routers"=>["192.168.124.1", "192.168.124.2"],
          "domain_name_servers"=>["192.168.123.1", "192.168.122.250"]
        }
      },{
         "network"=>"192.168.1.0",
         "netmask"=>"255.255.255.128",
         "options" => {}
    }].to_set
    assert_equal expected, data.to_set
  end

  def test_api_02_get_network
    get "/192.168.122.0"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    expected_reservations = [{
        "hostname"   => "test.example.com",
        "ip"         => "192.168.122.1",
        "mac"        => "00:11:bb:cc:dd:ee",
      }, {
        "hostname"   => "ten.example.com",
        "ip"         => "192.168.122.10",
        "mac"        => "10:10:10:10:10:10",
      }, {
        "hostname"   => "undeleted.example.com",
        "ip"         => "192.168.122.35",
        "mac"        => "10:10:10:10:30:30",
      },{
        "hostname"   => "mac441ea173366b.example.com",
        "ip"         => "192.168.122.44",
        "mac"        => "44:1e:a1:73:36:6b",
      }, {
        "hostname"   => "quux.example.org",
        "ip"         => "192.168.122.53",
        "mac"        => "52:54:00:31:a3:97",
      }].to_set
    expected_leases = [{
        "ip"     => "192.168.122.2",
        "mac"    => "00:aa:bb:cc:dd:ee",
        "starts" => date_format("Sat Jul 12 10:08:29 UTC 2014"),
        "ends"   => nil,
        "state"  => "active"
      },{
        "ip"     => "192.168.122.89",
        "mac"    => "ec:f4:bb:c6:ca:fe",
        "starts" => date_format("2014-10-16 12:59:40 UTC"),
        "ends"   => date_format("2199-01-01 00:00:01 UTC"),
        "state"  => "active"
      }, {
        "ip"     => "192.168.122.7",
        "mac"    => "44:1e:a1:73:39:91",
        "starts" => date_format("2014-12-09 14:29:01 UTC"),
        "ends"   => date_format("2114-12-09 14:39:01 UTC"),
        "state"  => "active"
      }].to_set

    assert_equal expected_reservations, data['reservations'].to_set
    assert_equal expected_leases, data['leases'].to_set
  end

  def test_api_03_get_network_unused_ip
    Proxy::DHCP::Subnet.any_instance.stubs(:tcp_pingable?).returns(false)
    Proxy::DHCP::Subnet.any_instance.stubs(:icmp_pingable?).returns(false)

    get "/192.168.122.0/unused_ip"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    expected = {"ip"=>"192.168.122.3"}
    assert_equal expected, data

    assert_equal true, File.exist?('test/tmp/foreman-proxy_192.168.122.0_24.tmp')
    assert_equal '1', File.read('test/tmp/foreman-proxy_192.168.122.0_24.tmp')
  end

  def test_api_04_get_network_unused_ip_again
    Proxy::DHCP::Subnet.any_instance.stubs(:tcp_pingable?).returns(false)
    Proxy::DHCP::Subnet.any_instance.stubs(:icmp_pingable?).returns(false)

    get "/192.168.122.0/unused_ip"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    expected = {"ip"=>"192.168.122.4"}
    assert_equal expected, data

    assert_equal true, File.exist?('test/tmp/foreman-proxy_192.168.122.0_24.tmp')
    assert_equal '2', File.read('test/tmp/foreman-proxy_192.168.122.0_24.tmp')
  end

  def test_api_05_get_network_record
    get "/192.168.122.0/192.168.122.1"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    expected = {
      "hostname" =>"test.example.com",
      "ip"       =>"192.168.122.1",
      "mac"      =>"00:11:bb:cc:dd:ee",
      "subnet"   =>"192.168.122.0/255.255.255.0"
    }
    assert_equal expected, data
  end

  # New record with identical duplicate contents should be a successful no-op
  def test_api_06_create_record_existing
    params = {
      "hostname" => "test.example.com",
      "ip"       => "192.168.122.1",
      "mac"      => "00:11:bb:cc:dd:ee",
      "network"  => "192.168.122.0/255.255.255.0",
    }
    post "/192.168.122.0", params
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = ''
    assert_equal expected, last_response.body
  end

  # New record with conflicting contents should be a failure
  def test_api_07_create_record_collision
    params = {
      "hostname" => "test.example.com",
      "ip"       => "192.168.122.1",
      "mac"      => "00:aa:bb:cc:dd:ee",
      "network"  => "192.168.122.0/255.255.255.0",
    }
    post "/192.168.122.0", params
    assert last_response.client_error?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = 'Record 192.168.122.0/192.168.122.1 already exists'
    assert_equal expected, last_response.body
    assert_equal 409, last_response.status
  end

  def test_api_08_create_record_new
    params = {
      "hostname" => "ten.example.com",
      "ip"       => "192.168.122.10",
      "mac"      => "10:10:10:10:10:10",
      "network"  => "192.168.122.0/255.255.255.0",
      # TODO: test some optional vendor options here
    }
    post "/192.168.122.0", params
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = ''
    assert_equal expected, last_response.body
  end

  def test_api_09_delete_record
    delete "/192.168.122.0/192.168.122.10"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = ''
    assert_equal expected, last_response.body
  end

  def test_api_10_delete_record_notfound
    delete "/192.168.122.0/192.168.122.11"
    assert last_response.not_found?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    expected = 'Record 192.168.122.0/192.168.122.11 not found'
    assert_equal expected, last_response.body
  end

  def test_sparc_host_creation
    sub = Proxy::DHCP::Subnet.new('192.168.122.0','255.255.255.0')

    Proxy::DHCP::Server::ISC.any_instance.stubs(:find_subnet).returns(sub)

    post '/192.168.122.10', sparc_attrs
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
  end
end
