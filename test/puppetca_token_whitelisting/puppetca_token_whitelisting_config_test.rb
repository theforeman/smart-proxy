require 'test_helper'
require 'puppetca/puppetca'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting_plugin'

class PuppetCATokenWhitelistingConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::TokenWhitelisting::Plugin.load_test_settings()
    assert_equal false, Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.sign_all
    assert_equal '/var/lib/foreman-proxy/tokens.yml', Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.tokens_file
    assert_equal 360, Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.token_ttl
    assert_equal nil, Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.certificate
  end
end
