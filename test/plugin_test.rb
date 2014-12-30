require 'test_helper'

class Proxy::Plugin
  class << self
    attr_writer :settings
  end
end

class PluginTest < Test::Unit::TestCase
  class TestPlugin1 < Proxy::Plugin; end
  def test_log_used_default_settings
    plugin = TestPlugin1.new
    plugin.class.settings = ::Proxy::Settings::Plugin.new({:a => 'a', :b => 'b'}, {})

    assert_equal ':a: a, :b: b, :enabled: false', plugin.log_used_default_settings
  end

  class TestPlugin2 < Proxy::Plugin; plugin :test2, '1.0'; end
  def test_http_rackup_returns_empty_string_with_missing_rackup_path
    assert_equal "", TestPlugin2.new.http_rackup
    assert_equal "", TestPlugin2.new.https_rackup
  end

  # version number follows core (non-release) standard with -develop, which has special handling
  class TestPlugin3 < Proxy::Plugin; plugin :test3, '1.5-develop'; end
  class TestPlugin4 < Proxy::Plugin; plugin :test4, '1.0'; requires :test3, '~> 1.5.0'; end
  def test_satisfied_dependency
    assert_nothing_raised do
      TestPlugin3.new.validate_dependencies!(TestPlugin3.dependencies)
    end
    assert_nothing_raised do
      TestPlugin4.new.validate_dependencies!(TestPlugin4.dependencies)
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
end
