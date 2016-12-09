require 'test_helper'
require 'realm/configuration_loader'
require 'realm/realm_plugin'
require 'realm/dependency_injection'
require 'realm/realm_api'

ENV['RACK_ENV'] = 'test'

class RealmApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  class RealmProviderForTesting
    def create(realm, hostname, attrs)
    end

    def delete(realm, hostname)
    end

    def find(hostname)
      true
    end
  end

  def app
    @app = Proxy::Realm::Api.new
    @app.helpers.realm_provider = @provider
    @app
  end

  def setup
    @provider = RealmProviderForTesting.new
  end

  def test_create_host
    realm = 'test_realm'
    hostname = 'host.test'
    @provider.expects(:create).with(realm, hostname, has_entry('another' => 'another')).returns({})
    post '/test_realm', :hostname => hostname, :another => 'another'
    assert_equal 200, last_response.status
  end

  def test_create_host_returns_error_when_exception_is_raised
    @provider.expects(:create).raises(Exception)
    post '/test_realm', :hostname => 'host.test'
    assert_equal 400, last_response.status
  end

  def test_delete_host
    @provider.expects(:find).with('host.test').returns(true)
    @provider.expects(:delete).with('test_realm', 'host.test')
    delete '/test_realm/host.test'
    assert_equal 200, last_response.status
  end

  def test_delete_host_returns_error_if_host_not_found
    @provider.expects(:find).with('host.test').returns(false)
    delete '/test_realm/host.test'
    assert_equal 404, last_response.status
  end

  def test_delete_host_returns_error_when_exception_is_raised
    @provider.expects(:delete).raises(Exception)
    delete '/test_realm/host.test'
    assert_equal 400, last_response.status
  end
end
