require 'test_helper'

class Proxy::Plugins
  def self.reset
    @loaded = []
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

  class TestPlugin1D < Proxy::Plugin; plugin :test_plugin_1d, "1.0"; default_settings :enabled => true; end
  class TestPlugin1E < Proxy::Provider; plugin :test_plugin_1e, "1.0", :factory => nil; default_settings :enabled => true; end
  def test_find_provider
    Proxy::Plugins.update([{:name => :test_plugin_1d, :instance => TestPlugin1D.new}, {:name => :test_plugin_1e, :instance => TestPlugin1E.new}])
    assert Proxy::Plugins.find_provider(:test_plugin_1e).is_a?(PluginTest::TestPlugin1E)
  end

  def test_find_provider_should_raise_exception_if_no_provider_exists
    assert_raises ::Proxy::PluginProviderNotFound do
      Proxy::Plugins.find_provider(:nonexistent)
    end
  end

  class TestPlugin1G < Proxy::Plugin; plugin :test_plugin_1g, "1.0"; default_settings :enabled => true; end
  def test_find_provider_should_raise_exception_if_provider_is_of_wrong_class
    Proxy::Plugins.update([{:name => :test_plugin_1g, :instance => TestPlugin1G.new}])
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
    loaded = [{ :name => :test3a, :version => "1.5-develop", :class => TestPlugin3a, :instance => TestPlugin3a.new, :enabled => true },
              { :name => :test3b, :version => "1.10.0-RC1", :class => TestPlugin3b, :instance => TestPlugin3b.new, :enabled => true },
              { :name => :test_plugin_4a, :version => "1.0", :class => TestPlugin4a, :instance => TestPlugin4a, :enabled => true },
              { :name => :test_plugin_4b, :version => "1.0", :class => TestPlugin4b, :instance => TestPlugin4b, :enabled => true }]

    assert_nothing_raised do
      TestPlugin3a.new.validate_dependencies!(loaded, TestPlugin3a.dependencies)
    end
    assert_nothing_raised do
      TestPlugin3b.new.validate_dependencies!(loaded, TestPlugin3b.dependencies)
    end
    assert_nothing_raised do
      TestPlugin4a.new.validate_dependencies!(loaded, TestPlugin4a.dependencies)
    end
    assert_nothing_raised do
      TestPlugin4b.new.validate_dependencies!(loaded, TestPlugin4b.dependencies)
    end
  end

  class TestPlugin5 < Proxy::Plugin; plugin :test5, '1.5'; end
  class TestPlugin6 < Proxy::Plugin; plugin :test6, '1.0'; requires :test5, '> 2.0'; end
  def test_unsatisified_dependency
    loaded = [{ :name => :test5, :version => "1.5", :class => TestPlugin5, :instance => TestPlugin5, :enabled => true },
              { :name => :test6, :version => "1.0", :class => TestPlugin6, :instance => TestPlugin6, :enabled => true }]

    assert_raise(::Proxy::PluginVersionMismatch) do
      TestPlugin6.new.validate_dependencies!(loaded, TestPlugin6.dependencies)
    end
  end

  class TestPlugin7 < Proxy::Plugin; plugin :test7, '1.0'; requires :unknown, '> 2.0'; end
  def test_missing_dependency
    assert_raise(::Proxy::PluginNotFound) do
      TestPlugin7.new.validate_dependencies!([], TestPlugin7.dependencies)
    end
  end

  class TestPlugin9 < Proxy::Plugin; plugin :test9, '1.0'; default_settings :enabled => true; end
  def test_configure_plugin_pass_validation
    plugin = TestPlugin9.new
    Proxy::BundlerHelper.expects(:require_groups).with(:default, :test9)
    plugin.configure_plugin([])
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

    assert_equal plugin.http_rackup, ''
    assert_equal plugin.https_rackup, "require 'test12/test12_api'"
  end

  class TestPlugin13 < Proxy::Plugin; uses_provider; default_settings :use_provider => :test_plugin_14; end
  class TestPlugin14 < Proxy::Provider; end
  def test_successful_validation_of_prerequisites
    loaded = [{ :name => :test_plugin_14, :version => "1.0", :class => TestPlugin14, :instance => TestPlugin14.new, :enabled => true }]
    assert_nothing_raised do
      TestPlugin13.new.validate_prerequisites_enabled!(loaded, [:test_plugin_14])
    end
  end

  def test_validation_of_prerequisites_when_provider_is_disabled
    loaded = [{ :name => :test_plugin_14, :version => "1.0", :class => TestPlugin14, :instance => TestPlugin14.new}]
    assert_raise ::Proxy::PluginMisconfigured do
      TestPlugin13.new.validate_prerequisites_enabled!(loaded, [:test_plugin_14])
    end
  end

  def test_validation_of_prerequisites_when_provider_was_not_loaded
    assert_raise ::Proxy::PluginMisconfigured do
      TestPlugin13.new.validate_prerequisites_enabled!([], [:test_plugin_14])
    end
  end
end
