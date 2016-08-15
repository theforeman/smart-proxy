require 'test_helper'
require 'dns_libvirt/plugin_configuration'
require 'dns_libvirt/dns_libvirt_main'

class DnsLibvirtConfigTest < Test::Unit::TestCase
  def test_default_settings
    ::Proxy::Dns::Libvirt::Plugin.load_test_settings({})
    assert_equal 'default', Proxy::Dns::Libvirt::Plugin.settings.network
  end
end

class DnsLibvirtWiringTest < Test::Unit::TestCase
  def setup
    @container = ::Proxy::DependencyInjection::Container.new
    @config = ::Proxy::Dns::Libvirt::PluginConfiguration.new
  end

  def test_libvirt_network_wiring
    @config.load_dependency_injection_wirings(@container, :url => 'test:///default', :network => 'test_network')
    network = @container.get_dependency(:libvirt_network)

    assert_equal 'test:///default', network.url
    assert_equal 'test_network', network.network
  end

  def test_dns_provider_wiring
    @config.load_dependency_injection_wirings(@container, :url => 'test:///default', :network => 'test_network')
    provider = @container.get_dependency(:dns_provider)

    assert !provider.libvirt_network.nil?
    assert_equal 'test_network', provider.network
  end
end
