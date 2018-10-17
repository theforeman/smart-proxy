require 'test_helper'
require 'puppetca/puppetca'

class PuppetCAConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::Plugin.load_test_settings({})
    assert_equal 'puppetca_hostname_whitelisting', Proxy::PuppetCa::Plugin.settings.use_provider
  end

  def test_set_puppet_cert_ca_provider_for_4_2
    Proxy::PuppetCa::Plugin.load_test_settings(:puppet_version => '4.2')
    configuration = Proxy::PuppetCa::PluginConfiguration.new
    assert_includes configuration.load_programmable_settings(Proxy::PuppetCa::Plugin.settings)[:use_provider], :puppetca_puppet_cert
  end

  def test_set_puppet_cert_ca_provider_for_4_10_1
    Proxy::PuppetCa::Plugin.load_test_settings(:puppet_version => '4.10.1')
    configuration = Proxy::PuppetCa::PluginConfiguration.new
    assert_includes configuration.load_programmable_settings(Proxy::PuppetCa::Plugin.settings)[:use_provider], :puppetca_puppet_cert
  end

  def test_set_puppet_cert_ca_provider_for_6_6
    Proxy::PuppetCa::Plugin.load_test_settings(:puppet_version => '6.0')
    configuration = Proxy::PuppetCa::PluginConfiguration.new
    assert_includes configuration.load_programmable_settings(Proxy::PuppetCa::Plugin.settings)[:use_provider], :puppetca_http_api
  end
end
