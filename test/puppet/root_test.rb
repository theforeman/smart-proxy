require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'puppet_proxy/puppet'
require 'puppet_proxy_puppet_api/puppet_proxy_puppet_api'

class PuppetApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_features
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppet.yml').returns({enabled: true, puppet_version: '5.5.8'})
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppet_proxy_puppet_api.yml').returns({puppet_url: 'https://puppet.example.com:8140'})

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['puppet']
    refute_nil(mod)
    assert_nil(mod['capabilities'])

    expected_settings = {'use_provider' => ['puppet_proxy_puppet_api']}
    assert_equal(expected_settings, mod['settings'])
  end
end
