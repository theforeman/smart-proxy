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

  def test_trusted_hosts_matches
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').returns('host.example.org')
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.ok?
  end

  def test_trusted_hosts_forbids_access
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').returns('eve.example.org')
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.forbidden?
  end

  def test_trusted_hosts_failed_resolv
    Proxy::SETTINGS.expects(:trusted_hosts).at_least_once.returns(['host.example.org'])
    Resolv.any_instance.expects(:getname).with('10.0.0.1').raises(Resolv::ResolvError, 'no name')
    get '/test', nil, 'REMOTE_ADDR' => '10.0.0.1'
    assert last_response.forbidden?
  end

  class TestApp < ::Sinatra::Base
    authorize_with_trusted_hosts

    get '/test' do
      'success'
    end
  end
end
