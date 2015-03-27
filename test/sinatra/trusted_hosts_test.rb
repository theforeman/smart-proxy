require 'test_helper'
require 'json'
require 'sinatra/base'

ENV['RACK_ENV'] = 'test'

class TrustedHostsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    TestApp.new
  end

  def test_root
    get '/test'
    assert last_response.ok?
  end

  def test_trusted_hosts_unset
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(nil)
    get '/test'
    assert last_response.ok?
  end

  def test_trusted_hosts_empty
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns([])
    get '/test'
    assert last_response.forbidden?
  end

  def test_trusted_hosts_http_matches
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').returns('host.example.org')
    Resolv.any_instance.expects(:getaddresses).with('host.example.org').returns(['10.0.0.1'])
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.ok?
  end

  def test_trusted_hosts_http_no_forward_verify
    Proxy::SETTINGS.expects(:forward_verify).at_least_once.returns(false)
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['noreverse.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').returns('noreverse.example.org')
    # would be nice, but does not work
    # see: http://pbrisbin.com/posts/beware_never_expectations/
    #Resolv.any_instance.expects(:getaddresses).with('noreverse.example.org').never()
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.ok?
  end

  def test_trusted_hosts_http_forbid_forward_verify
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').returns('host.example.org')
    Resolv.any_instance.expects(:getaddresses).with('host.example.org').returns(['10.0.0.2'])
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.forbidden?
  end

  def test_trusted_hosts_http_forbids_access
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').returns('eve.example.org')
    Resolv.any_instance.expects(:getaddresses).with('eve.example.org').returns(['10.0.0.3'])
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.forbidden?
  end

  def test_trusted_hosts_http_failed_resolv
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').raises(Resolv::ResolvError, 'no name')
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.forbidden?
  end

  def test_trusted_hosts_https_matches
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    OpenSSL::X509::Certificate.stubs(:new).returns(OpenSSL::X509::Certificate)
    OpenSSL::X509::Certificate.expects(:subject).at_least_once.returns('CN=host.example.org,...')
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1', 'HTTPS' => 'on', 'SSL_CLIENT_CERT' => 'FOOBAR'
    assert last_response.ok?
  end

  def test_trusted_hosts_https_invalid_cert
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1', 'HTTPS' => 'on', 'SSL_CLIENT_CERT' => 'FOOBAR'
    assert last_response.forbidden?
  end

  def test_trusted_hosts_https_forbids_access
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    OpenSSL::X509::Certificate.stubs(:new).returns(OpenSSL::X509::Certificate)
    OpenSSL::X509::Certificate.expects(:subject).at_least_once.returns('CN=eve.example.org,...')
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1', 'HTTPS' => 'on', 'SSL_CLIENT_CERT' => 'FOOBAR'
    assert last_response.forbidden?
  end

  class TestApp < ::Sinatra::Base
    authorize_with_trusted_hosts

    get '/test' do
      'success'
    end
  end
end
