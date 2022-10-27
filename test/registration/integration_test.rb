require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'templates/templates'
require 'registration/registration'

class RegistrationApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_with_templates
    Proxy::LegacyModuleLoader.any_instance.expects(:load_configuration_file).with('templates.yml').returns(enabled: true, template_url: 'http://smart-proxy.example.com:8000')
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('registration.yml').returns(enabled: true)

    get '/features'
    response = JSON.parse(last_response.body)
    mod = response['registration']

    refute_nil(mod)
    assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:registration])
    assert_equal({'registration_url' => nil}, response['registration']['settings'])
  end

  def test_without_templates
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('registration.yml').returns(enabled: true)

    get '/features'
    response = JSON.parse(last_response.body)
    mod = response['registration']

    refute_nil(mod)
    assert_equal('failed', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:registration])
  end

  def test_chomp_trailing_slash
    registration_url = 'https://loadbalancer.example.com'

    Proxy::LegacyModuleLoader.any_instance.expects(:load_configuration_file).with('templates.yml').returns(enabled: true, template_url: 'http://smart-proxy.example.com:8000')
    Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('registration.yml').returns(enabled: true, registration_url: "#{registration_url}/")

    get '/features'
    response = JSON.parse(last_response.body)

    assert_equal({'registration_url' => registration_url}, response['registration']['settings'])
  end
end
