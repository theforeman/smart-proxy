require 'test_helper'
require 'net/http'

class SSLClientVerificationIntegrationTest < Test::Unit::TestCase
  include Proxy::IntegrationTestCase

  class TestAPIWithSSLClientAuth < ::Sinatra::Base
    helpers ::Proxy::Helpers
    authorize_with_ssl_client
    get('/') { 'Success' }
  end

  class TestPluginWithSSLClientAuth < ::Proxy::Plugin
    class << self
      def http_rackup
        'run SSLClientVerificationIntegrationTest::TestAPIWithSSLClientAuth'
      end
      alias_method :https_rackup, :http_rackup
    end
  end

  def test_http
    launch protocol: 'http', plugins: [TestPluginWithSSLClientAuth]
    res = Net::HTTP.get_response('localhost', '/', @settings.http_port)
    assert_kind_of Net::HTTPSuccess, res
    assert_equal 'Success', res.body
  end

  def test_https_no_cert
    launch_https
    http = Net::HTTP.new('localhost', @settings.https_port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    res = http.get('/')
    assert_kind_of Net::HTTPForbidden, res
  end

  def test_https_cert_from_different_authority
    launch_https
    http = Net::HTTP.new('localhost', @settings.https_port)
    http.use_ssl = true
    http.ca_file = File.join(fixtures, 'certs', 'ca.pem')
    http.cert    = OpenSSL::X509::Certificate.new(File.read(File.join(fixtures, 'certs', 'badclient.example.com.pem')))
    http.key     = OpenSSL::PKey::RSA.new(File.read(File.join(fixtures, 'private_keys', 'badclient.example.com.pem')))
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    assert_raise EOFError, OpenSSL::SSL::SSLError do
      http.get('/')
    end
  end

  def test_https_cert
    launch_https
    http = Net::HTTP.new('localhost', @settings.https_port)
    http.use_ssl = true
    http.ca_file = File.join(fixtures, 'certs', 'ca.pem')
    http.cert    = OpenSSL::X509::Certificate.new(File.read(File.join(fixtures, 'certs', 'client.example.com.pem')))
    http.key     = OpenSSL::PKey::RSA.new(File.read(File.join(fixtures, 'private_keys', 'client.example.com.pem')))
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    res = http.get('/')
    assert_kind_of Net::HTTPSuccess, res
    assert_equal 'Success', res.body
  end

  private

  def launch_https
    launch protocol: 'https', plugins: [TestPluginWithSSLClientAuth],
           settings: {
             ssl_private_key: File.join(fixtures, 'private_keys', 'server.example.com.pem'),
             ssl_certificate: File.join(fixtures, 'certs', 'server.example.com.pem'),
             ssl_ca_file:     File.join(fixtures, 'certs', 'ca.pem'),
           }
  end

  def fixtures
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'fixtures', 'ssl'))
  end
end
