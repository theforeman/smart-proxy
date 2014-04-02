require 'test_helper'
require 'dns/dns'
require 'dns/providers/nsupdate'

class DnsConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
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
end
