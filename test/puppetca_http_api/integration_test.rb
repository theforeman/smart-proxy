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
    ssl_ca = Tempfile.new('ssl_ca')
    ssl_cert = Tempfile.new('ssl_cert')
    ssl_key = Tempfile.new('ssl_key')

    begin
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppetca.yml').returns(enabled: true, puppet_version: '6.0.0')
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppetca_hostname_whitelisting.yml').returns({})
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppetca_http_api.yml').returns(
        puppet_url: 'https://puppet.example.com:8140',
        puppet_ssl_ca: ssl_ca.path,
        puppet_ssl_cert: ssl_cert.path,
        puppet_ssl_key: ssl_key.path
      )

      get '/features'

      response = JSON.parse(last_response.body)

      mod = response['puppetca']
      refute_nil(mod)
      assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:puppetca])
      assert_equal([], mod['capabilities'])

      expected_settings = {'use_provider' => ['puppetca_hostname_whitelisting', 'puppetca_http_api']}
      assert_equal(expected_settings, mod['settings'])
    ensure
      ssl_ca.unlink
      ssl_cert.unlink
      ssl_key.unlink
    end
  end
end
