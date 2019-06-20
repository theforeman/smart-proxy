require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'bmc/bmc_plugin'
require 'bmc/ipmi'

class BmcApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_features
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('bmc.yml').returns(enabled: true, bmc_default_provider: 'freeipmi')
    Proxy::BMC::IPMI.stubs(:providers_installed).returns([])

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['bmc']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:bmc])
    assert_equal(['redfish', 'shell', 'ssh'], mod['capabilities'])

    assert_equal({}, mod['settings'])
  end

  def test_features_with_freeipmi_installed
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('bmc.yml').returns(enabled: true, bmc_default_provider: 'freeipmi')
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['bmc']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:bmc])
    assert_equal(['freeipmi', 'redfish', 'shell', 'ssh'], mod['capabilities'])

    assert_equal({}, mod['settings'])
  end
end
