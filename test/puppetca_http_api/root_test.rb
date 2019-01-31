require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'puppetca/puppetca'
require 'puppetca_hostname_whitelisting/puppetca_hostname_whitelisting'
require 'puppetca_http_api/puppetca_http_api'

class PuppetcaApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_features
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppetca.yml').returns({enabled: true, puppet_version: '6.0.0'})
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppetca_hostname_whitelisting.yml').returns({})
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppetca_http_api.yml').returns({puppet_url: 'https://puppet.example.com:8140'})

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['puppetca']
    refute_nil(mod)
    assert_nil(mod['capabilities'])
    assert_nil(mod['settings'])
  end

end
