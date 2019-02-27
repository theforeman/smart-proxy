require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'dns/dns'
require 'dns_dnscmd/dns_dnscmd'

class DnsCmdApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_features
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('dns.yml').returns(enabled: true, use_provider: 'dns_dnscmd')
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('dns_dnscmd.yml').returns(dns_server: 'dns.example.com')

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['dns']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:dns])
    assert_equal([], mod['capabilities'])

    expected_settings = {'use_provider' => 'dns_dnscmd'}
    assert_equal(expected_settings, mod['settings'])
  end
end
