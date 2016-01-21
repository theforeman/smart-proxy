require 'test_helper'

class PluginInitializerTest < Test::Unit::TestCase
  class TestPlugin23 < Proxy::Plugin; plugin :test_plugin_13, "1.0"; default_settings :enabled => true; end
  class TestPlugin24 < Proxy::Plugin; plugin :test_plugin_14, "1.0"; default_settings :enabled => true; end
  class TestPlugin25 < Proxy::Plugin; plugin :test_plugin_15, "1.0"; uses_provider; default_settings :enabled => true, :use_provider => :test_plugin_16; end
  class TestPlugin26 < Proxy::Provider; plugin :test_plugin_16, "1.0"; default_settings :enabled => true; end

  def test_build_configuration_order_without_provider
    loaded = [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin23, :instance => TestPlugin23.new },
              { :name => :test_plugin_14, :version => "1.0", :class => TestPlugin24, :instance => TestPlugin24.new }]
    order = Proxy::PluginInitializer.new.build_configuration_order(loaded)
    assert_equal loaded, order
  end

  def test_build_configuration_order_with_provider
    loaded = [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin23, :instance => (p1 = TestPlugin23.new) },
              { :name => :test_plugin_15, :version => "1.0", :class => TestPlugin25, :instance => (p2 = TestPlugin25.new) },
              { :name => :test_plugin_16, :version => "1.0", :class => TestPlugin26, :instance => (p3 = TestPlugin26.new) }]
    order = Proxy::PluginInitializer.new.build_configuration_order(loaded)
    assert_equal [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin23, :instance => p1 },
                  { :name => :test_plugin_16, :version => "1.0", :class => TestPlugin26, :instance => p3 },
                  { :name => :test_plugin_15, :version => "1.0", :class => TestPlugin25, :instance => p2 }],
                 order
  end

  class TestPlugin27 < Proxy::Plugin; uses_provider; default_settings :enabled => false, :use_provider => :test_plugin_16; end
  def test_build_configureation_order_with_disabled_plugin
    loaded = [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin23, :instance => (p1 = TestPlugin23.new) },
              { :name => :test_plugin_17, :version => "1.0", :class => TestPlugin27, :instance => TestPlugin27.new },
              { :name => :test_plugin_16, :version => "1.0", :class => TestPlugin26, :instance => TestPlugin26.new }]
    order = Proxy::PluginInitializer.new.build_configuration_order(loaded)
    assert_equal [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin23, :instance => p1 }],
                 order
  end

  def test_configure_plugins_sets_enabled_flag
    ordered = [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin23, :instance => (p1 = TestPlugin23.new) }]
    enabled = Proxy::PluginInitializer.new.configure_plugins(ordered, ordered)
    assert_equal [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin23, :instance => p1, :enabled => true }],
                 enabled
  end

  class TestPlugin28 < Proxy::Plugin; plugin :test_plugin_18, "1.0"; default_settings :enabled => true; def configure_plugin(_); false; end; end
  def test_configure_plugins_does_not_set_enabled_flag_for_failed_plugins
    expected = ordered = [{ :name => :test_plugin_18, :version => "1.0", :class => TestPlugin28, :instance => TestPlugin28.new }]
    assert_equal expected, Proxy::PluginInitializer.new.configure_plugins(ordered, ordered)
  end
end
