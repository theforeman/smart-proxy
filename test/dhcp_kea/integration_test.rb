require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'dhcp/dhcp'
require 'dhcp_kea/dhcp_kea'

class DhcpKeaApiFeaturesTest < SmartProxyRootApiTestCase
  def test_features
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('dhcp.yml').returns(enabled: true, use_provider: 'dhcp_kea')
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('dhcp_kea.yml').returns(
      dhcp_kea_url: 'http://127.0.0.1:8000/',
      dhcp_kea_verify_ssl: true,
      dhcp_kea_lease_timeout: 60
    )

    # Mock the KEA client to avoid actual API calls during feature loading
    Proxy::DHCP::Kea::KeaApiClient.any_instance.stubs(:list_subnets).returns([])

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['dhcp']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:dhcp])
    assert_equal(['dhcp_filename_hostname', 'dhcp_filename_ipv4'], mod['capabilities'].sort)

    expected_settings = {'use_provider' => 'dhcp_kea'}
    assert_equal(expected_settings, mod['settings'])
  end
end
