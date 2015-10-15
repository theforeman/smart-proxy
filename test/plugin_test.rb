require 'test_helper'

class Proxy::Plugins
  def self.reset
    @@enabled = {}
  end
end

class Proxy::Plugin
  class << self
    attr_writer :settings
  end
end

class PluginTest < Test::Unit::TestCase
  def setup
    ::Proxy::Plugins.reset
  end

  class TestPlugin1 < Proxy::Plugin; end
  def test_log_used_default_settings
    plugin = TestPlugin1.new
    plugin.class.settings = ::Proxy::Settings::Plugin.new({:a => 'a', :b => 'b'}, {})

    assert_equal ':a: a, :b: b, :enabled: false', plugin.log_used_default_settings
  end

  class TestPlugin1A < Proxy::Plugin; plugin :test_plugin_1a, "1.0"; default_settings :enabled => true; end
  class TestPlugin1B < Proxy::Plugin; end
  class TestPlugin1C < Proxy::Provider; plugin :test_plugin_1c, "1.0", :factory => nil; default_settings :enabled => true; end
  def test_enabled_plugins
    TestPlugin1A.new.configure_plugin
    TestPlugin1C.new.configure_plugin

    assert_equal 1, Proxy::Plugins.enabled_plugins.size
    assert Proxy::Plugins.enabled_plugins.first.is_a?(PluginTest::TestPlugin1A)
  end

  class TestPlugin1D < Proxy::Plugin; plugin :test_plugin_1d, "1.0"; default_settings :enabled => true; end
  class TestPlugin1E < Proxy::Provider; plugin :test_plugin_1e, "1.0", :factory => nil; default_settings :enabled => true; end
  class TestPlugin1F < Proxy::Provider; plugin :test_plugin_1f, "1.0", :factory => nil; default_settings :enabled => true; end
  def test_find_provider
    TestPlugin1E.new.configure_plugin
    TestPlugin1F.new.configure_plugin

    assert Proxy::Plugins.find_provider(:test_plugin_1e).is_a?(PluginTest::TestPlugin1E)
  end

  def test_find_provider_should_raise_exception_if_no_provider_exists
    assert_raises ::Proxy::PluginProviderNotFound do
      Proxy::Plugins.find_provider(:nonexistent)
    end
  end

  class TestPlugin1G < Proxy::Plugin; plugin :test_plugin_1g, "1.0"; default_settings :enabled => true; end
  def test_find_provider_should_raise_exception_if_provider_is_of_wrong_class
    TestPlugin1G.new.configure_plugin

    assert_equal 1, Proxy::Plugins.enabled_plugins.size
    assert_raises ::Proxy::PluginProviderNotFound do
      Proxy::Plugins.find_provider(:test_plugin_1g)
    end
  end

  class TestPlugin2 < Proxy::Plugin; plugin :test2, '1.0'; end
  def test_http_rackup_returns_empty_string_with_missing_rackup_path
    assert_equal "", TestPlugin2.new.http_rackup
    assert_equal "", TestPlugin2.new.https_rackup
  end

  # version number follows core (non-release) standard with -develop, which has special handling
  class TestPlugin3a < Proxy::Plugin; plugin :test3a, '1.5-develop'; end
  class TestPlugin3b < Proxy::Plugin; plugin :test3b, '1.10.0-RC1'; end
  class TestPlugin4a < Proxy::Plugin; plugin :test4a, '1.0'; requires :test3a, '~> 1.5.0'; end
  class TestPlugin4b < Proxy::Plugin; plugin :test4b, '1.0'; requires :test3b, '~> 1.10.0'; end
  def test_satisfied_dependency
    assert_nothing_raised do
      TestPlugin3a.new.validate_dependencies!(TestPlugin3a.dependencies)
    end
    assert_nothing_raised do
      TestPlugin3b.new.validate_dependencies!(TestPlugin3b.dependencies)
    end
    assert_nothing_raised do
      TestPlugin4a.new.validate_dependencies!(TestPlugin4a.dependencies)
    end
    assert_nothing_raised do
      TestPlugin4b.new.validate_dependencies!(TestPlugin4b.dependencies)
    end
  end

  class TestPlugin5 < Proxy::Plugin; plugin :test5, '1.5'; end
  class TestPlugin6 < Proxy::Plugin; plugin :test6, '1.0'; requires :test5, '> 2.0'; end
  def test_unsatisified_dependency
    assert_raise(::Proxy::PluginVersionMismatch) do
      TestPlugin6.new.validate_dependencies!(TestPlugin6.dependencies)
    end
  end

  class TestPlugin7 < Proxy::Plugin; plugin :test7, '1.0'; requires :unknown, '> 2.0'; end
  def test_missing_dependency
    assert_raise(::Proxy::PluginNotFound) do
      TestPlugin7.new.validate_dependencies!(TestPlugin7.dependencies)
    end
  end

  class TestPlugin8 < Proxy::Plugin; plugin :test8, '1.0'; requires :unknown, '> 2.0'; end
  def test_configure_plugin_fail_validation
    TestPlugin8.settings = ::Proxy::Settings::Plugin.new({:enabled => true}, {})
    plugin = TestPlugin8.new
    plugin.expects(:validate_dependencies!).with(TestPlugin8.dependencies).raises(::Proxy::PluginVersionMismatch)
    Proxy::Plugins.expects(:plugin_enabled).never
    Proxy::Plugins.expects(:disable_plugin).with(:test8)
    plugin.configure_plugin
  end

  class TestPlugin9 < Proxy::Plugin; plugin :test9, '1.0'; end
  def test_configure_plugin_pass_validation
    TestPlugin9.settings = ::Proxy::Settings::Plugin.new({:enabled => true}, {})
    plugin = TestPlugin9.new
    plugin.expects(:validate_dependencies!).with(TestPlugin9.dependencies)
    Proxy::Plugins.expects(:plugin_enabled).with(:test9, plugin)
    Proxy::BundlerHelper.expects(:require_groups).with(:default, :test9)
    Proxy::Plugins.expects(:disable_plugin).never
    plugin.configure_plugin
  end

  class TestPlugin10 < Proxy::Plugin; plugin :test10, '1.0'; end
  def test_enable_of_only_http_is_successful
    TestPlugin10.settings = ::Proxy::Settings::Plugin.new({:enabled => 'http'}, {})
    assert TestPlugin10.http_enabled?
    assert !TestPlugin10.https_enabled?
  end

  class TestPlugin11 < Proxy::Plugin; plugin :test11, '1.0'; end
  def test_enable_of_only_https_is_successful
    TestPlugin11.settings = ::Proxy::Settings::Plugin.new({:enabled => 'https'}, {})
    assert TestPlugin11.https_enabled?
    assert !TestPlugin11.http_enabled?
  end

  class TestPlugin12 < Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :enabled => 'https'
    plugin :test12, '1.0'
  end

  def test_plugin_loads_http_rack_path
    assert !TestPlugin12.http_enabled?
    assert TestPlugin12.https_enabled?
    assert TestPlugin12.plugin_name, 'test12'
    # Ensure that the content is read from 'http_config.ru'
    File.stubs(:read).returns("require 'test12/test12_api'")
    plugin = TestPlugin12.new
    plugin.configure_plugin
    assert_equal plugin.http_rackup, ''
    assert_equal plugin.https_rackup, "require 'test12/test12_api'"
  end

  class TestPlugin13 < Proxy::Plugin; end
  class TestPlugin14 < Proxy::Plugin; end
  def test_build_configuration_order
    loaded = [{ :name => :test_plugin_13, :version => "1.0", :class => TestPlugin13 },
              { :name => :test_plugin_14, :version => "1.0", :class => TestPlugin14 }]
    order = Proxy::Plugins.build_configuration_order(loaded)
    assert_equal loaded, order
  end

  class TestPlugin15 < Proxy::Plugin; end
  class TestPlugin16 < Proxy::Plugin; initialize_after :test_plugin_17; end
  class TestPlugin17 < Proxy::Plugin; end
  def test_build_configuration_order_with_prerequisites
    loaded = [{ :name => :test_plugin_15, :version => "1.0", :class => TestPlugin15 },
              { :name => :test_plugin_16, :version => "1.0", :class => TestPlugin16 },
              { :name => :test_plugin_17, :version => "1.0", :class => TestPlugin17 }]
    order = Proxy::Plugins.build_configuration_order(loaded)
    assert_equal [{ :name => :test_plugin_15, :version => "1.0", :class => TestPlugin15 },
                  { :name => :test_plugin_17, :version => "1.0", :class => TestPlugin17 },
                  { :name => :test_plugin_16, :version => "1.0", :class => TestPlugin16 }],
                 order
  end

  class TestPlugin18 < Proxy::Plugin; end
  class TestPlugin19 < Proxy::Plugin; initialize_after :test_plugin_20; end
  class TestPlugin20 < Proxy::Plugin; end
  class TestPlugin21 < Proxy::Plugin; initialize_after :test_plugin_20; end
  def test_build_configuration_order_repeated_prerequisites
    loaded = [{ :name => :test_plugin_18, :version => "1.0", :class => TestPlugin18 },
              { :name => :test_plugin_19, :version => "1.0", :class => TestPlugin19 },
              { :name => :test_plugin_20, :version => "1.0", :class => TestPlugin20 },
              { :name => :test_plugin_21, :version => "1.0", :class => TestPlugin21 }]
    order = Proxy::Plugins.build_configuration_order(loaded)
    assert_equal [{ :name => :test_plugin_18, :version => "1.0", :class => TestPlugin18 },
                  { :name => :test_plugin_20, :version => "1.0", :class => TestPlugin20 },
                  { :name => :test_plugin_19, :version => "1.0", :class => TestPlugin19 },
                  { :name => :test_plugin_21, :version => "1.0", :class => TestPlugin21 }],
                 order
  end

  class TestPlugin22 < Proxy::Plugin; uses_provider; initialize_after :first_prerequisite; end
  def test_use_provider_affects_initialization_order
    TestPlugin22.settings = ::Proxy::Settings::Plugin.new({:use_provider => 'test_provider'}, {})
    assert_equal [:first_prerequisite, :test_provider], TestPlugin22.initialize_after
  end

  class TestPlugin23 < Proxy::Plugin; end
  def test_multiple_initialize_after
    TestPlugin23.initialize_after :first_prerequisite
    TestPlugin23.initialize_after :second_prerequisite, :third_prerequisite
    assert_equal [:first_prerequisite, :second_prerequisite, :third_prerequisite],
                 TestPlugin23.initialize_after
  end
end
