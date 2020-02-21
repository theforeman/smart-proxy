require 'test_helper'
require 'json'
require 'root/root'
require 'root/root_v2_api'

ENV['RACK_ENV'] = 'test'

class TestPlugin1 < ::Proxy::Plugin
  plugin :foreman_proxy, "0.0.1"
end

class TestPlugin2 < ::Proxy::Plugin
  plugin :test2, "0.0.1"
end

class TestPlugin3 < ::Proxy::Plugin
  plugin :test3, "0.0.1"
end

class RootV2ApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::RootV2Api.new
  end

  def test_features
    proc2 = -> { ['a', 'b'] }
    proc3 = -> { raise "Should not be called" }
    ::Proxy::Plugins.any_instance.expects(:loaded).returns(
      [{:name => :foreman_proxy, :version => "0.0.1", :class => TestPlugin1, :state => :running},
       {:name => :test2, :version => "0.0.1", :class => TestPlugin2, :state => :running, :capabilities => ['c', proc2], :settings => 'foo'},
       {:name => :test3, :version => "0.0.1", :class => TestPlugin3, :state => :disabled, :capabilities => ['d', proc3]}])
    get "/features"

    response = JSON.parse(last_response.body)

    test2 = response['test2']
    test3 = response['test3']

    assert test2
    assert_equal ['a', 'b', 'c'], test2['capabilities']
    assert_equal test2['settings'], 'foo'

    assert test3
    assert_equal ['d'], test3['capabilities']
  end
end
