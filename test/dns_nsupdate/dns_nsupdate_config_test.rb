require 'test_helper'
require 'dns/dns'
require 'dns_nsupdate/dns_nsupdate'
require 'dns_nsupdate/dns_nsupdate_gss'

class DnsNsupdateConfigTest < Test::Unit::TestCase
  def test_nsupdate_default_settings
    Proxy::Dns::Nsupdate::Plugin.load_test_settings({})

    assert_equal "localhost", Proxy::Dns::Nsupdate::Plugin.settings.dns_server
    assert_nil Proxy::Dns::Nsupdate::Plugin.settings.dns_key
  end

  def test_nsupdate_gss_default_settings
    Proxy::Dns::NsupdateGSS::Plugin.load_test_settings({})

    assert_equal "localhost", Proxy::Dns::NsupdateGSS::Plugin.settings.dns_server
    assert_nil Proxy::Dns::NsupdateGSS::Plugin.settings.dns_key
    assert_equal '/usr/share/foreman-proxy/dns.keytab', Proxy::Dns::NsupdateGSS::Plugin.settings.dns_tsig_keytab
    assert_equal 'DNS/host.example.com@EXAMPLE.COM', Proxy::Dns::NsupdateGSS::Plugin.settings.dns_tsig_principal
  end
end
