require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'tftp/tftp_plugin'

class TftpApiFeaturesTest < SmartProxyRootApiTestCase
  def test_features
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('tftp.yml').returns(enabled: true, tftproot: '/var/lib/tftpboot', tftp_servername: 'tftp.example.com', enable_system_image: false)

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['tftp']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:tftp])
    assert_equal([], mod['capabilities'])

    expected_settings = { 'http_port' => 1234, 'tftp_servername' => 'tftp.example.com' }
    assert_equal(expected_settings, mod['settings'])
  end

  def test_features_with_enable_system_image
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('tftp.yml').returns(enabled: true, tftproot: '/var/lib/tftpboot', tftp_servername: 'tftp.example.com', enable_system_image: true)

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['tftp']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:tftp])
    assert_equal(['system_image'], mod['capabilities'])

    expected_settings = { 'http_port' => 1234, 'tftp_servername' => 'tftp.example.com' }
    assert_equal(expected_settings, mod['settings'])
  end
end
