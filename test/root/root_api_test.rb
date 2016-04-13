require 'test_helper'
require 'json'
require 'root/root_plugin'
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
    ::Proxy::Plugins.any_instance.stubs(:enabled_plugins).returns([TestPlugin2, TestPlugin3, TestPlugin0])
    get "/features"
    assert_equal ['test2', 'test3'], JSON.parse(last_response.body)
  end

  def test_version
    ::Proxy::Plugins.any_instance.stubs(:enabled_plugins).returns([TestPlugin2, TestPlugin3, TestPlugin0])
    get "/version"
    assert_equal(Proxy::VERSION, JSON.parse(last_response.body)["version"])
    modules = Hash[::Proxy::Plugins.instance.enabled_plugins.collect {|plugin| [plugin.plugin_name.to_s, plugin.version.to_s]}].reject { |key| key == 'foreman_proxy' }
    assert_equal(modules, JSON.parse(last_response.body)["modules"])
  end
end
