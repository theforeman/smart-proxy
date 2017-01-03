require 'test_helper'
require 'dns_common/dns_common'
require 'dns_nsupdate/dns_nsupdate'
require 'dns_nsupdate/dns_nsupdate_main'
require 'dns_nsupdate/dns_nsupdate_gss'
require 'dns_nsupdate/dns_nsupdate_gss_main'

class DnsNsupdateConfigTest < Test::Unit::TestCase
  def test_nsupdate_default_settings
    Proxy::Dns::Nsupdate::Plugin.load_test_settings({})

    assert_equal "localhost", Proxy::Dns::Nsupdate::Plugin.settings.dns_server
    assert_nil Proxy::Dns::Nsupdate::Plugin.settings.dns_key
  end

  def test_nsupdate_gss_default_settings
    Proxy::Dns::NsupdateGSS::Plugin.load_test_settings({})

    assert_equal "localhost", Proxy::Dns::NsupdateGSS::Plugin.settings.dns_server
    assert_equal '/usr/share/foreman-proxy/dns.keytab', Proxy::Dns::NsupdateGSS::Plugin.settings.dns_tsig_keytab
    assert_equal 'DNS/host.example.com@EXAMPLE.COM', Proxy::Dns::NsupdateGSS::Plugin.settings.dns_tsig_principal
  end
end

require 'dns_nsupdate/nsupdate_configuration'

class DnsNsupdateWiringTest < Test::Unit::TestCase
  def setup
    @container = ::Proxy::DependencyInjection::Container.new
    @config = ::Proxy::Dns::Nsupdate::PluginConfiguration.new
  end

  def test_dns_provider_wiring
    @config.load_dependency_injection_wirings(@container, :dns_server => 'dnscmd_test', :dns_ttl => 999, :dns_key => 'dns_key')
    provider = @container.get_dependency(:dns_provider)

    assert_equal 'dnscmd_test', provider.server
    assert_equal 999, provider.ttl
    assert_equal 'dns_key', provider.dns_key
  end
end

class DnsNsupdateGSSWiringTest < Test::Unit::TestCase
  def setup
    @container = ::Proxy::DependencyInjection::Container.new
    @config = ::Proxy::Dns::NsupdateGSS::PluginConfiguration.new
  end

  def test_dns_provider_wiring
    @config.load_dependency_injection_wirings(@container, :dns_server => 'dnscmd_test', :dns_ttl => 999,
                                              :dns_tsig_keytab => 'keytab', :dns_tsig_principal => 'principal')
    provider = @container.get_dependency(:dns_provider)

    assert_equal 'dnscmd_test', provider.server
    assert_equal 999, provider.ttl
    assert_equal 'keytab', provider.tsig_keytab
    assert_equal 'principal', provider.tsig_principal
  end
end

