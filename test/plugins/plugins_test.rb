require 'test_helper'

class PluginsTest < Test::Unit::TestCase
  def setup
    @plugins = ::Proxy::Plugins.new
  end

  class TestPlugin1 < Proxy::Plugin
    plugin :plugin_1, "1.0"
    default_settings :enabled => true
  end

  class TestPlugin2 < Proxy::Provider
    plugin :plugin_2, "1.0"
    default_settings :enabled => true
  end

  def test_find_provider
    @plugins.update([{:name => :plugin_1, :class => TestPlugin1}, {:name => :plugin_2, :class => TestPlugin2}])
    assert_equal PluginsTest::TestPlugin2, @plugins.find_provider(:plugin_2)
  end

  def test_find_provider_should_raise_exception_if_no_provider_exists
    assert_raises(::Proxy::PluginProviderNotFound) { @plugins.find_provider(:nonexistent) }
  end

  class TestPlugin3 < Proxy::Plugin
    plugin :plugin_3, "1.0"
    default_settings :enabled => true
  end

  def test_find_provider_should_raise_exception_if_provider_is_of_wrong_class
    @plugins.update([{:name => :plugin_3, :class => TestPlugin3}])
    assert_raises(::Proxy::PluginProviderNotFound) { @plugins.find_provider(:plugin_3) }
  end
end
