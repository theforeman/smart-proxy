require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'puppet_proxy/puppet'

class PuppetFeaturesTest < Test::Unit::TestCase
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
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('puppet.yml').returns(
        enabled: true,
        puppet_url: 'https://puppet.example.com:8140',
        puppet_ssl_ca: ssl_ca.path,
        puppet_ssl_cert: ssl_cert.path,
        puppet_ssl_key: ssl_key.path
      )

      get '/features'

      response = JSON.parse(last_response.body)

      mod = response['puppet']
      refute_nil(mod)
      assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:puppet])
      assert_equal([], mod['capabilities'])

      expected_settings = {'puppet_url' => 'https://puppet.example.com:8140'}
      assert_equal(expected_settings, mod['settings'])
    ensure
      ssl_ca.unlink
      ssl_cert.unlink
      ssl_key.unlink
    end
  end
end
