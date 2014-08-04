require 'test_helper'
require 'dns/dns'
require 'dns/providers/nsupdate'
require 'dns/providers/nsupdate_gss'

class DnsConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::Dns::Plugin.load_test_settings({})
    assert_equal 'nsupdate', Proxy::Dns::Plugin.settings.dns_provider
  end

  def test_initialize_nsupdate_returns_no_error_with_missing_key_setting
    Proxy::Dns::Plugin.settings.stubs(:dns_key).returns(nil)
    assert Proxy::Dns::Nsupdate.new(:fqdn => 'example.com')
  end

  def test_initialize_nsupdate_returns_error_with_missing_key_file
    Proxy::Dns::Plugin.settings.stubs(:dns_key).returns('./no-such-key')
    assert_raise RuntimeError do
      Proxy::Dns::Nsupdate.new(:fqdn => 'example.com')
    end
  end

  def test_initialize_nsupdate_gss_succeeds
    File.expects(:exist?).with('./key').returns(true)
    assert Proxy::Dns::NsupdateGSS.new(:fqdn => 'example.com', :tsig_keytab => './key', :tsig_principal => 'a@B')
  end

  def test_initialize_nsupdate_gss_returns_error_with_missing_keykey_file
    File.expects(:exist?).with('./key').returns(false)
    assert_raise RuntimeError do
      Proxy::Dns::NsupdateGSS.new(:fqdn => 'example.com', :tsig_keytab => './key', :tsig_principal => 'a@B')
    end
  end
end
