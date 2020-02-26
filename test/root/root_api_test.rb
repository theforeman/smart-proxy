require 'test_helper'
require 'json'
require 'root/root'
require 'root/root_api'

ENV['RACK_ENV'] = 'test'

class TestPlugin0 < ::Proxy::Plugin
  plugin :foreman_proxy, "0.0.1"
end

class TestPlugin2 < ::Proxy::Plugin
  plugin :test2, "0.0.1"
end

class TestPlugin3 < ::Proxy::Plugin
  plugin :test3, "0.0.1"
end

class RootApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::RootApi.new
  end

  def test_features
    ::Proxy::Plugins.any_instance.expects(:loaded).returns(
      [{:name => :foreman_proxy, :version => "0.0.1", :class => TestPlugin0, :state => :running},
       {:name => :test2, :version => "0.0.1", :class => TestPlugin2, :state => :running},
       {:name => :test2, :version => "0.0.1", :class => TestPlugin3, :state => :disabled}])
    get "/features"
    assert_equal ['test2'], JSON.parse(last_response.body)
  end

  def test_version
    all_modules = [{:name => :foreman_proxy, :version => "0.0.1", :class => TestPlugin0, :state => :running},
                   {:name => :test2, :version => "0.0.1", :class => TestPlugin2, :state => :running},
                   {:name => :test2, :version => "0.0.1", :class => TestPlugin3, :state => :disabled}]

    ::Proxy::Plugins.any_instance.expects(:loaded).returns(all_modules)

    get "/version"
    assert_equal(Proxy::VERSION, JSON.parse(last_response.body)["version"])
    modules = Hash[all_modules.collect { |plugin| [plugin[:name].to_s, plugin[:version].to_s] }].reject { |key| key == 'foreman_proxy' }
    assert_equal(modules, JSON.parse(last_response.body)["modules"])
  end
end
