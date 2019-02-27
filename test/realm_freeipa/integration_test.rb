require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'realm/realm'
require 'realm_freeipa/realm_freeipa'

class RealmFreeipaApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_features
    keytab = Tempfile.new('keytab')
    ipa_config = Tempfile.new('ipa_config')

    begin
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('realm.yml').returns(enabled: true, use_provider: 'realm_freeipa')
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('realm_freeipa.yml').returns(
        keytab_path: keytab.path,
        principal: 'realm-proxy@EXAMPLE.COM',
        ipa_config: ipa_config.path
      )

      get '/features'

      response = JSON.parse(last_response.body)

      mod = response['realm']
      refute_nil(mod)
      assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:realm])
      assert_equal([], mod['capabilities'])

      expected_settings = {'use_provider' => 'realm_freeipa'}
      assert_equal(expected_settings, mod['settings'])
    ensure
      keytab.unlink
      ipa_config.unlink
    end
  end
end
