require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'logs/logs'

class LogsApiFeaturesTest < SmartProxyRootApiTestCase
  def test_features
    Proxy::LegacyModuleLoader.any_instance.expects(:load_configuration_file).with('logs.yml').returns(enabled: true)

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['logs']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:logs])
    assert_equal([], mod['capabilities'])

    assert_equal({}, mod['settings'])
  end
end
