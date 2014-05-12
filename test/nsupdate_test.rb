require 'test_helper'
require 'proxy/dns'
require 'proxy/dns/nsupdate'

class NsupdateTest < Test::Unit::TestCase
  def test_initialize_nsupdate_returns_no_error_with_missing_key_setting
    SETTINGS.stubs(:dns_key).returns(nil)
    assert Proxy::DNS::Nsupdate.new(:fqdn => 'example.com')
  end

  def test_initialize_nsupdate_returns_error_with_missing_key_file
    SETTINGS.stubs(:dns_key).returns('./no-such-key')
    assert_raise RuntimeError do
      Proxy::DNS::Nsupdate.new(:fqdn => 'example.com')
    end
  end
end
