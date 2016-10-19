require 'test_helper'
require 'dns_dnscmd/plugin_configuration'
require 'dns_dnscmd/dns_dnscmd_plugin'

class DnsCmdConfigTest < Test::Unit::TestCase
  def test_default_configuration
    ::Proxy::Dns::Dnscmd::Plugin.load_test_settings({})
    assert_equal 'localhost', ::Proxy::Dns::Dnscmd::Plugin.settings.dns_server
  end
end

class DnsCmdWiringTest < Test::Unit::TestCase
  def setup
    @container = ::Proxy::DependencyInjection::Container.new
    @config = ::Proxy::Dns::Dnscmd::PluginConfiguration.new
  end

  def test_dns_provider_wiring
    @config.load_dependency_injection_wirings(@container, :dns_server => 'dnscmd_test', :dns_ttl => 999, :dns_ptr_rewritemap => {'a' => 'b'})
    provider = @container.get_dependency(:dns_provider)

    assert_equal 'dnscmd_test', provider.server
    assert_equal 999, provider.ttl
    assert_equal ({'a' => 'b'}), provider.ptr_rewritemap
  end
end
