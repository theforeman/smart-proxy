require 'test_helper'
require 'json'
require 'root/root_v2_api'
require 'dhcp/dhcp'
require 'dhcp_isc/dhcp_isc'

class DhcpIscApiFeaturesTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PluginInitializer.new(Proxy::Plugins.instance).initialize_plugins
    Proxy::RootV2Api.new
  end

  def test_features
    config = Tempfile.new('config')
    leases = Tempfile.new('leases')

    begin
      config.close
      leases.close
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('dhcp.yml').returns(enabled: true, use_provider: 'dhcp_isc')
      Proxy::DefaultModuleLoader.any_instance.expects(:load_configuration_file).with('dhcp_isc.yml').returns(config: config.path, leases: leases.path)

      get '/features'

      response = JSON.parse(last_response.body)

      mod = response['dhcp']
      refute_nil(mod)
      assert_equal('running', mod['state'], Proxy::LogBuffer::Buffer.instance.info[:failed_modules][:dhcp])
      assert_equal(["dhcp_filename_hostname", "dhcp_filename_ipv4"], mod['capabilities'])

      expected_settings = {'use_provider' => 'dhcp_isc'}
      assert_equal(expected_settings, mod['settings'])
    ensure
      config.unlink
      leases.unlink
    end
  end
end
