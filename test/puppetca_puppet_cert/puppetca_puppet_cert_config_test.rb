require 'test_helper'
require 'puppetca_puppet_cert/puppetca_puppet_cert'

class PuppetCaPuppetCertConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::PuppetcaPuppetCert::Plugin.load_test_settings({})
    assert_equal '/var/lib/puppet/ssl', Proxy::PuppetCa::PuppetcaPuppetCert::Plugin.settings.ssldir
  end
end
