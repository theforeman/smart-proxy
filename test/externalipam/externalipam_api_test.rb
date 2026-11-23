require 'test_helper'
require 'externalipam/dependency_injection'

ENV['RACK_ENV'] = 'test'

# Test IPAM provider
class ExternalIpamTestProvider
  def get_next_ip(mac, cidr, group_name)
    { data: "192.0.2.1" }
  end

  def get_ipam_subnet(cidr, group_name)
    { data: {
      id: "33",
      subnet: "192.0.2.0",
      description: "Subnet description",
      mask: "24" },
    }
  end

  def get_ipam_group(group_name)
    { data: {
      id: 1,
      name: "Group 1",
      description: "This is a group" },
    }
  end

  def ipam_groups
    { data: [
      { id: 1, name: "Group 1", description: "This is group 1" },
      { id: 2, name: "Group 2", description: "This is group 2" },
    ]}
  end

  def get_ipam_subnets(group_name)
    { data: [
      { subnet: "192.0.2.0", mask: "24", description: "This is a subnet" },
      { subnet: "198.51.100.0", mask: "24", description: "This is another subnet" },
    ]}
  end

  def add_ip_to_subnet(ip, add_ip_params)
    nil
  end

  def delete_ip_from_subnet(ip, del_ip_params)
    nil
  end

  def ip_exists?(ip, subnet_id, group_name)
    true
  end

  def groups_supported?
    true
  end

  def authenticated?
    true
  end
end

# Inject test IPAM provider
module Proxy::Ipam
  module DependencyInjection
    include Proxy::DependencyInjection::Accessors
    def container_instance
      Proxy::DependencyInjection::Container.new do |container|
        container.dependency :externalipam_client, ExternalIpamTestProvider
      end
    end
  end
end

require 'externalipam/ipam_api'

class ExternalIpamApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::Ipam::Api.new
  end

  def setup
    @invalid_address = "1234.1234.1234.1234"
    @valid_address = "192.0.2.0"
    @invalid_prefix = "XY"
    @valid_prefix = "24"
    @invalid_mac = "bad_mac"
    @valid_mac = "b6:9d:1e:13:2d:2c"
  end

  def test_get_next_ip_throws_error_when_address_invalid
    get "/subnet/#{@invalid_address}/#{@valid_prefix}/next_ip?mac=#{@valid_mac}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_get_next_ip_throws_error_when_prefix_invalid
    get "/subnet/#{@valid_address}/#{@invalid_prefix}/next_ip?mac=#{@valid_mac}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_get_next_ip_throws_error_when_mac_addr_is_invalid
    get "/subnet/#{@valid_address}/#{@valid_prefix}/next_ip?mac=#{@invalid_mac}"
    assert_equal 400, last_response.status
    assert_match /Invalid MAC/, last_response.body
  end

  def test_get_next_ip_suceeds_when_mac_addr_is_valid
    get "/subnet/#{@valid_address}/#{@valid_prefix}/next_ip?mac=#{@valid_mac}"
    assert_equal 200, last_response.status
  end

  def test_get_next_ip_returns_success_when_all_params_are_valid
    get "/subnet/#{@valid_address}/#{@valid_prefix}/next_ip?mac=#{@valid_mac}"
    assert_equal 200, last_response.status
    assert_match /data/, last_response.body
  end

  def test_get_ipam_subnet_throws_error_when_address_invalid
    get "/subnet/#{@invalid_address}/#{@valid_prefix}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_get_ipam_subnet_throws_error_when_prefix_invalid
    get "/subnet/#{@valid_address}/#{@invalid_prefix}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_get_ipam_subnet_throws_error_when_address_is_nil
    get "/subnet//#{@valid_prefix}"
    assert_equal 404, last_response.status
  end

  def test_get_ipam_subnet_throws_error_when_prefix_is_nil
    get "/subnet/#{@valid_address}/"
    assert_equal 404, last_response.status
  end

  def test_get_ipam_subnet_returns_success_when_all_params_valid
    get "/subnet/#{@valid_address}/#{@valid_prefix}"
    assert_equal 200, last_response.status
    assert_match /data/, last_response.body
  end

  def test_get_groups_should_return_success_when_supported
    get "/groups"
    assert_equal 200, last_response.status
  end

  def test_get_ipam_group_throws_error_when_group_name_is_nil
    get "/group/"
    assert_equal 404, last_response.status
  end

  def test_get_ipam_group_returns_success_when_group_name_is_specified
    get "/groups/testgroup"
    assert_equal 200, last_response.status
    assert_match /data/, last_response.body
  end

  def test_get_ipam_subnets_throws_error_when_group_name_is_nil
    get "/group//subnets"
    assert_equal 404, last_response.status
  end

  def test_get_ipam_subnets_returns_success_when_group_name_is_specified
    get "/groups/testgroup/subnets"
    assert_equal 200, last_response.status
    assert_match /data/, last_response.body
  end

  def test_get_ip_throws_error_when_address_invalid
    get "/subnet/#{@invalid_address}/#{@valid_prefix}/#{@valid_address}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_get_ip_throws_error_when_prefix_invalid
    get "/subnet/#{@valid_address}/#{@invalid_prefix}/#{@valid_address}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_get_ip_returns_error_when_invalid_ip_provided
    get "/subnet/#{@valid_address}/#{@valid_prefix}/#{@invalid_address}"
    assert_equal 400, last_response.status
    assert_match /Invalid IP Address/, last_response.body
  end

  def test_get_ip_throws_error_when_ip_address_does_not_exist_in_cidr
    get "/subnet/192.0.2.0/24/221.34.56.3"
    assert_equal 400, last_response.status
    assert_match /not in/, last_response.body
  end

  def test_get_ip_returns_success_when_ip_address_exists_in_cidr
    get "/subnet/192.0.2.0/24/192.0.2.1"
    assert_equal 200, last_response.status
    assert_match /true/, last_response.body
  end

  def test_put_ip_throws_error_when_address_is_nil
    post "/subnet//#{@valid_prefix}/#{@valid_address}"
    assert_equal 404, last_response.status
  end

  def test_put_ip_throws_error_when_prefix_is_nil
    post "/subnet/#{@valid_address}//#{@valid_address}"
    assert_equal 404, last_response.status
  end

  def test_put_ip_throws_error_when_ip_address_is_nil
    post "/subnet/#{@valid_address}/#{@valid_prefix}/"
    assert_equal 404, last_response.status
  end

  def test_put_ip_throws_error_when_address_invalid
    post "/subnet/#{@invalid_address}/#{@valid_prefix}/#{@valid_address}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_put_ip_throws_error_when_prefix_invalid
    post "/subnet/#{@valid_address}/#{@invalid_prefix}/#{@valid_address}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_put_ip_returns_error_when_invalid_ip_provided
    post "/subnet/#{@valid_address}/#{@valid_prefix}/#{@invalid_address}"
    assert_equal 400, last_response.status
    assert_match /Invalid IP Address/, last_response.body
  end

  def test_delete_ip_throws_error_when_address_is_nil
    delete "/subnet//#{@valid_prefix}/#{@valid_address}"
    assert_equal 404, last_response.status
  end

  def test_delete_ip_throws_error_when_prefix_is_nil
    delete "/subnet/#{@valid_address}//#{@valid_address}"
    assert_equal 404, last_response.status
  end

  def test_delete_ip_throws_error_when_ip_address_is_nil
    delete "/subnet/#{@valid_address}/#{@valid_prefix}/"
    assert_equal 404, last_response.status
  end

  def test_delete_ip_throws_error_when_address_invalid
    delete "/subnet/#{@invalid_address}/#{@valid_prefix}/#{@valid_address}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_delete_ip_throws_error_when_prefix_invalid
    delete "/subnet/#{@valid_address}/#{@invalid_prefix}/#{@valid_address}"
    assert_equal 400, last_response.status
    assert_match /invalid address/, last_response.body
  end

  def test_delete_ip_returns_error_when_invalid_ip_provided
    delete "/subnet/#{@valid_address}/#{@valid_prefix}/#{@invalid_address}"
    assert_equal 400, last_response.status
    assert_match /Invalid IP Address/, last_response.body
  end
end
