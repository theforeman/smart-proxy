require 'test_helper'
require 'tempfile'
require 'fileutils'
require 'openssl'
require 'yaml'
require 'json'

require 'puppetca/puppetca'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting_autosigner'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting_csr'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting_token_storage'

class PuppetCaTokenWhitelistingAutosignerTest < Test::Unit::TestCase
  def setup
    @file = Tempfile.new('autosign_test')
    begin
      ## Setup
      FileUtils.cp './test/fixtures/puppetca/tokens.yml', @file.path
    rescue
      @file.close
      @file.unlink
      @file = nil
    end
    @autosigner = Proxy::PuppetCa::TokenWhitelisting::Autosigner.new
    @autosigner.stubs(:tokens_file).returns(@file.path)
    rsa_cert = OpenSSL::PKey::RSA.new File.read './test/fixtures/puppetca/rsa_cert.pem'
    @autosigner.stubs(:smartproxy_cert).returns(rsa_cert)
    @autosigner.stubs(:token_ttl).returns(360)
  end

  def teardown
    @file.close
    @file.unlink
  end

  def test_should_list_autosign_entries
    assert_equal @autosigner.autosign_list, ['foo.example.com', 'test.bar.example.com']
  end

  def test_should_add_autosign_entry
    @autosigner.autosign 'foobar.example.com', 0
    assert_equal @autosigner.autosign_list, ['foo.example.com', 'test.bar.example.com', 'foobar.example.com']
  end

  def test_should_create_correct_token
    response = @autosigner.autosign 'baz.example.com', 0
    token = JSON.parse(response)['generated_token']
    decoded = JWT.decode(token, @autosigner.smartproxy_cert.public_key, true, algorithm: 'RS512')
    assert_equal decoded.first['certname'], 'baz.example.com'
    assert((decoded.first['exp'] - Time.now.to_i - 360 * 60).abs < 100)
  end

  def test_should_remove_autosign_entry
    @autosigner.disable 'foo.example.com'
    assert_equal @autosigner.autosign_list, ['test.bar.example.com']
  end

  def test_should_validate_on_sign_all
    @autosigner.stubs(:sign_all).returns(true)
    assert_true @autosigner.validate_csr ''
  end

  def test_should_call_verification
    csr_example = File.read './test/fixtures/puppetca/csr_example.pem'
    @autosigner.expects(:validate_token).with('1234').returns(true)
    assert_true @autosigner.validate_csr csr_example
  end

  def test_should_validate_a_correct_token
    response = @autosigner.autosign 'signme.example.com', 0
    token = JSON.parse(response)['generated_token']

    assert_true @autosigner.validate_token token
  end

  def test_should_not_validate_expired_token
    payload = { certname: 'foo.example.com', exp: Time.now.to_i - 10 }
    token = JWT.encode payload, @autosigner.smartproxy_cert, 'RS512'

    assert_false @autosigner.validate_token token
  end

  def test_should_not_validate_token_with_invalid_certname
    payload = { certname: 'unknown.example.com', exp: Time.now.to_i + 999_999 }
    token = JWT.encode payload, @autosigner.smartproxy_cert, 'RS512'

    assert_false @autosigner.validate_token token
  end

  def test_should_not_validate_token_with_unkown_signature
    unknown_cert = OpenSSL::PKey::RSA.generate 2048
    payload = { certname: 'foo.example.com', exp: Time.now.to_i + 999_999 }
    token = JWT.encode payload, unknown_cert, 'RS512'

    assert_false @autosigner.validate_token token
  end
end
