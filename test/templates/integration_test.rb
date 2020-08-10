require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'templates/templates'

class TemplatesApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_features
    Proxy::LegacyModuleLoader.any_instance.expects(:load_configuration_file).with('templates.yml').returns(enabled: true, template_url: 'http://smart-proxy.example.com:8000')

    get '/features'

    response = JSON.parse(last_response.body)

    mod = response['templates']
    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:templates])
    assert_equal(['global_registration'], mod['capabilities'])

    assert_equal({'template_url' => 'http://smart-proxy.example.com:8000'}, mod['settings'])
  end
end
