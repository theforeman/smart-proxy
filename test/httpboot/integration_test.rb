require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'httpboot/httpboot_plugin'

class HttpbootApiFeaturesTest < SmartProxyRootApiTestCase
  def test_features
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('httpboot.yml').returns(enabled: true, root_dir: '/var/lib/tftpboot')

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['httpboot']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:httpboot])
    assert_equal([], mod['capabilities'])

    expected_settings = {'http_port' => nil, 'https_port' => 8443}
    assert_equal(expected_settings, mod['settings'])
  end

  def test_features_http
    Proxy::SETTINGS.http_port = 1234
    Proxy::SETTINGS.https_port = 5678
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('httpboot.yml').returns(enabled: 'http', root_dir: '/var/lib/tftpboot')

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['httpboot']
    refute_nil(mod)
    assert(mod['http_enabled'])
    refute(mod['https_enabled'])
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:httpboot])
    assert_equal([], mod['capabilities'])

    expected_settings = {'http_port' => 1234, 'https_port' => nil}
    assert_equal(expected_settings, mod['settings'])
  end
end
