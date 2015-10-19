require 'test_helper'
require 'dns_dnscmd/dns_dnscmd_plugin'

class DnsCmdConfigTest < Test::Unit::TestCase
  def test_default_config
    ::Proxy::Dns::Dnscmd::Plugin.load_test_settings({})
    assert_equal 'localhost', ::Proxy::Dns::Dnscmd::Plugin.settings.dns_server
  end
end
