require 'test_helper'

require 'puppetca/puppetca'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting_csr'

class PuppetCaTokenWhitelistingCSRTest < Test::Unit::TestCase
  def setup
    @csr_example = File.read './test/fixtures/puppetca/csr_example.pem'
  end

  def test_should_extract_correct_attribute
    req = Proxy::PuppetCa::TokenWhitelisting::CSR.new @csr_example
    assert_equal '1234', req.challenge_password
  end

  def test_should_fail_on_invalid_csr
    @csr_example.slice!(42...69)
    assert_raise OpenSSL::X509::RequestError do
      Proxy::PuppetCa::TokenWhitelisting::CSR.new @csr_example
    end
  end
end
