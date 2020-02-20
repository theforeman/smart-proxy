require 'test_helper'

class PluginGroupTest < Test::Unit::TestCase
  def test_group_initial_state
    group = ::Proxy::PluginGroup.new(nil)

    assert !group.inactive?
    assert !group.http_enabled?
    assert !group.https_enabled?
  end

  def test_group_listening_ports_when_enabled_setting_is_set_to_http
    group = ::Proxy::PluginGroup.new(nil)
    group.update_group_initial_state('http')

    assert !group.inactive?
    assert group.http_enabled?
    assert !group.https_enabled?
  end

  def test_group_listening_ports_when_enabled_setting_is_set_to_https
    group = ::Proxy::PluginGroup.new(nil)
    group.update_group_initial_state('https')

    assert !group.inactive?
    assert !group.http_enabled?
    assert group.https_enabled?
  end

  def test_group_listening_ports_when_group_is_disabled
    group = ::Proxy::PluginGroup.new(nil)
    group.update_group_initial_state(false)

    assert group.inactive?
    assert !group.http_enabled?
    assert !group.https_enabled?
  end

  def test_group_listening_ports_when_group_failed
    group = ::Proxy::PluginGroup.new(nil)
    group.set_group_state_to_failed

    assert group.inactive?
    assert !group.http_enabled?
    assert !group.https_enabled?
  end

  class TestPlugin3 < Proxy::Plugin; plugin :test3, "1.0"; uses_provider; default_settings :enabled => true; end
  class TestPlugin4 < Proxy::Provider; plugin :test4, "1.0"; default_settings :enabled => true; end
  def test_resolve_providers
    TestPlugin3.settings = OpenStruct.new(:use_provider => :test4, :enabled => true)
    loaded = [{ :name => :test3, :version => "1.0", :class => TestPlugin3, :state => :uninitialized },
              { :name => :test4, :version => "1.0", :class => TestPlugin4, :state => :uninitialized }]

    group = ::Proxy::PluginGroup.new(TestPlugin3)
    providers = group.resolve_providers(loaded)

    assert_equal([TestPlugin4], providers)
    assert_equal([TestPlugin4, TestPlugin3], group.members)
  end

  class TestPlugin5 < Proxy::Plugin; plugin :test5, '1.0'; end
  class TestPlugin6 < Proxy::Plugin; plugin :test6, "1.0"; uses_provider; end
  def test_resolve_providers_should_fail_when_one_is_missing
    TestPlugin6.settings = OpenStruct.new(:use_provider => :non_existent, :enabled => true)
    loaded = [{ :name => :test5, :version => "1.0", :class => TestPlugin5, :state => :uninitialized },
              { :name => :test6, :version => "1.0", :class => TestPlugin6, :state => :uninitialized }]

    group = ::Proxy::PluginGroup.new(TestPlugin6)
    group.resolve_providers(loaded)

    assert_equal(:failed, group.state)
  end

  # version number follows core (non-release) standard with -develop, which has special handling
  class TestPlugin7 < Proxy::Plugin; plugin :test7, '1.5-develop'; end
  class TestPlugin8 < Proxy::Plugin; plugin :test8, '1.10.0-RC1'; end
  class TestPlugin9 < Proxy::Plugin; plugin :test9, '1.0'; requires :test7, '~> 1.5.0'; end
  class TestPlugin10 < Proxy::Plugin; plugin :test10, '1.0'; requires :test8, '~> 1.10.0'; end
  def test_validate_dependencies
    enabled = { :test7 => TestPlugin7, :test8 => TestPlugin8, :test9 => TestPlugin9, :test10 => TestPlugin10 }

    group1 = ::Proxy::PluginGroup.new(TestPlugin9)
    group1.validate_dependencies_or_fail(enabled)
    assert !group1.inactive?

    group2 = ::Proxy::PluginGroup.new(TestPlugin10)
    group2.validate_dependencies_or_fail(enabled)
    assert !group2.inactive?
  end

  class TestPlugin11 < Proxy::Plugin; plugin :test11, "1.0"; uses_provider; default_settings :enabled => true, :use_provider => :test12; end
  class TestPlugin12 < Proxy::Provider; plugin :test12, "1.0"; requires :test13, '~> 1.0'; default_settings :enabled => true; end
  class TestPlugin13 < Proxy::Plugin; plugin :test13, '1.0'; default_settings :enabled => true; end
  def test_validate_provider_dependencies
    group = ::Proxy::PluginGroup.new(TestPlugin11)
    group.validate_dependencies_or_fail(:test11 => TestPlugin11, :test12 => TestPlugin12, :test13 => TestPlugin13)
    assert !group.inactive?
  end

  class TestPlugin14 < Proxy::Plugin; plugin :test14, '1.0'; requires :test_non_existent, '1.0'; end
  def test_validate_dependencies_with_missing_dependency
    group = ::Proxy::PluginGroup.new(TestPlugin14)
    group.validate_dependencies_or_fail(:test14 => TestPlugin14)
    assert_equal(:failed, group.state)
  end

  def test_validate_dependencies_stops_services_on_failure
    group = ::Proxy::PluginGroup.new(TestPlugin14)
    group.expects(:stop_services)
    group.validate_dependencies_or_fail(:test14 => TestPlugin14)
  end

  class TestPluginForPassingLoadSettingsTest < ::Proxy::Plugin
    default_settings :enabled => true
  end
  def test_load_plugin_settings_updates_group_initial_state
    group = ::Proxy::PluginGroup.new(TestPluginForPassingLoadSettingsTest)
    TestPluginForPassingLoadSettingsTest.module_loader_class.any_instance.expects(:load_settings).returns(:enabled => true)

    assert !group.inactive?
    group.load_plugin_settings

    assert_equal :starting, group.state
    assert group.http_enabled?
    assert group.https_enabled?
  end

  class TestPluginForFailingLoadSettingsTest < ::Proxy::Plugin; end
  def test_load_plugin_settings_changes_state_to_failed_on_failure
    TestPluginForFailingLoadSettingsTest.module_loader_class.any_instance.expects(:load_settings).raises("FAILURE")
    group = ::Proxy::PluginGroup.new(TestPluginForFailingLoadSettingsTest)

    assert !group.inactive?
    group.load_plugin_settings
    assert_equal :failed, group.state
  end

  class TestProviderForFailingLoadSettingsTest < ::Proxy::Provider; end
  def test_load_provider_settings_changes_state_to_failed_on_failure
    TestProviderForFailingLoadSettingsTest.module_loader_class.any_instance.expects(:load_settings).raises("FAILURE")
    TestPluginForFailingLoadSettingsTest.settings = OpenStruct.new(:use_provider => :test_provider, :enabled => true)
    group = ::Proxy::PluginGroup.new(TestPluginForFailingLoadSettingsTest, [TestProviderForFailingLoadSettingsTest])

    assert !group.inactive?
    group.load_provider_settings
    assert_equal :failed, group.state
  end

  class PluginForSuccessfullConfigureTest < ::Proxy::Plugin; end
  def test_configure_changes_state_to_running_on_success
    group = ::Proxy::PluginGroup.new(PluginForSuccessfullConfigureTest)
    group.configure

    assert_equal :running, group.state
  end

  class PluginForFailingConfigureTest < ::Proxy::Plugin; end
  def test_configure_changes_state_to_failed_on_failure
    group = ::Proxy::PluginGroup.new(PluginForFailingConfigureTest)
    PluginForFailingConfigureTest.module_loader_class.any_instance.expects(:configure_plugin).raises("FAILED")

    assert !group.inactive?
    group.configure
    assert_equal :failed, group.state
  end

  def test_stop_services_called_if_group_runtime_configuration_fails
    group = ::Proxy::PluginGroup.new(PluginForFailingConfigureTest)
    PluginForFailingConfigureTest.module_loader_class.any_instance.expects(:configure_plugin).raises("FAILED")
    group.expects(:stop_services)

    group.configure
  end

  class TestStopServicesPlugin < ::Proxy::Plugin
    start_services :service_a
  end
  class TestStopServicesProvider < ::Proxy::Provider
    start_services :service_b
  end
  class TestStopServicesService
    attr_reader :state
    def start
      @state = :started
    end

    def stop
      @state = :stopped
    end
  end
  def test_stop_services
    di_container = ::Proxy::DependencyInjection::Container.new do |c|
      c.singleton_dependency :service_a, TestStopServicesService
      c.singleton_dependency :service_b, TestStopServicesService
    end
    group = ::Proxy::PluginGroup.new(TestStopServicesPlugin, [TestStopServicesProvider], di_container)

    assert_not_equal :stopped, di_container.get_dependency(:service_a).state
    assert_not_equal :stopped, di_container.get_dependency(:service_b).state

    group.stop_services

    assert_equal :stopped, di_container.get_dependency(:service_a).state
    assert_equal :stopped, di_container.get_dependency(:service_b).state
  end
end
