require 'test_helper'
require 'dns/dns'

class DnsConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::Dns::Plugin.load_test_settings({})
    assert_equal 'dns_nsupdate', Proxy::Dns::Plugin.settings.use_provider
    assert_equal 86_400, Proxy::Dns::Plugin.settings.dns_ttl
  end
end
