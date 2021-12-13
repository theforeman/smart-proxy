require 'test_helper'

class ModuleLoaderTest < Test::Unit::TestCase
  class TestPlugin < ::Proxy::Plugin; end

  def setup
    @loader = ::Proxy::DefaultModuleLoader.new(TestPlugin, ::Proxy::DependencyInjection::Container.new)
  end

  def test_merge_settings
    merged = @loader.merge_settings({:setting_a => "setting_a"}, :setting_b => "setting_b")
    assert_equal({:setting_a => "setting_a", :setting_b => "setting_b"}, merged)
  end

  def test_merge_settings_should_fail_when_duplicate_settings_detected
    assert_raises(Exception) { @loader.merge_settings({:duplicate => "first"}, :duplicate => "second") }
  end

  def test_merge_settings_should_ignore_enabled
    assert @loader.merge_settings({:enabled => true}, :enabled => false)[:enabled]
  end

  def test_load_configuration_returns_empty_hash_when_config_not_found
    assert_equal({}, @loader.load_configuration_file("non_existent_config"))
  end

  def test_compute_runtime_configuration_returns_original_settings_without_runtime_config_loader
    assert_equal({:setting => "value"}, @loader.load_programmable_settings(:setting => "value"))
  end

  class TestRuntimeConfig
    def load_programmable_settings(settings)
      settings[:another_setting] = "another_value"
      settings
    end
  end
  class TestPluginWithRuntimeConfigLoader < ::Proxy::Plugin
    load_programmable_settings TestRuntimeConfig
  end
  def test_compute_runtime_configuration_uses_runtime_config_loader
    loader = ::Proxy::DefaultModuleLoader.new(TestPluginWithRuntimeConfigLoader, nil)
    assert_equal({:another_setting => "another_value", :setting => "value"}, loader.load_programmable_settings(:setting => "value"))
  end

  class TestClassLoader; end
  class TestPluginWithClassLoader < ::Proxy::Plugin
    load_classes TestClassLoader
  end
  def test_load_classes_uses_class_loader
    TestClassLoader.any_instance.expects(:load_classes)
    ::Proxy::DefaultModuleLoader.new(TestPluginWithClassLoader, nil).load_classes
  end

  class TestPluginWithClassLoaderBlock < ::Proxy::Plugin
    class << self; attr_reader :block_executed; end
    load_classes { @block_executed = true }
  end
  def test_load_classes_uses_class_loader_block
    ::Proxy::DefaultModuleLoader.new(TestPluginWithClassLoaderBlock, nil).load_classes
    assert TestPluginWithClassLoaderBlock.block_executed
  end

  class TestPluginWithDefaultValues < ::Proxy::Plugin
    default_settings :default_1 => "one", :default_2 => "two"
  end
  def test_presence_validators_called_on_each_of_default_settings
    loader = ::Proxy::DefaultModuleLoader.new(TestPluginWithDefaultValues, nil)
    results = loader.validate_settings(TestPluginWithDefaultValues, :default_1 => "one", :default_2 => "two")
    assert results.include?(:class => ::Proxy::PluginValidators::Presence, :setting => :default_1, :args => nil, :predicate => nil)
    assert results.include?(:class => ::Proxy::PluginValidators::Presence, :setting => :default_2, :args => nil, :predicate => nil)
  end

  VALIDATOR_PREDICATE = ->(settings) { false }
  class TestPluginWithBuiltInValidators < ::Proxy::Plugin
    default_settings :default_1 => "one", :default_2 => "two"
    validate_presence :missing_setting, if: VALIDATOR_PREDICATE
    validate_readable :missing_path, if: VALIDATOR_PREDICATE
  end
  def test_presence_validator_called_with_predicate
    loader = ::Proxy::DefaultModuleLoader.new(TestPluginWithBuiltInValidators, nil)
    results = loader.validate_settings(TestPluginWithBuiltInValidators, :default_1 => "one", :default_2 => "two")
    assert_includes results, {:class => ::Proxy::PluginValidators::Presence, :setting => :default_1, :args => nil, :predicate => nil}
    assert_includes results, {:class => ::Proxy::PluginValidators::Presence, :setting => :default_2, :args => nil, :predicate => nil}
    assert_includes results, {:class => ::Proxy::PluginValidators::Presence, :setting => :missing_setting, :args => true, :predicate => VALIDATOR_PREDICATE}
    assert_includes results, {:class => ::Proxy::PluginValidators::FileReadable, :setting => :missing_path, :args => true, :predicate => VALIDATOR_PREDICATE}
  end

  class TestValidator < ::Proxy::PluginValidators::Base
    def validate!(settings)
      true
    end
  end
  class TestPluginWithCustomValidators < ::Proxy::Plugin
    load_validators :testing => TestValidator
    validate :setting, :testing => {:arg1 => "arg1", :arg2 => "arg2"}, :if => ->(settings) { settings[:evaluate] }
  end
  def test_validate_runtime_config_executes_custom_validators
    loader = ::Proxy::DefaultModuleLoader.new(TestPluginWithCustomValidators, nil)
    results = loader.validate_settings(TestPluginWithCustomValidators, :setting => "value", :evaluate => true)
    predicate = TestPluginWithCustomValidators.validations.first[:predicate]
    assert_equal([{:class => TestValidator, :setting => :setting, :args => {:arg1 => "arg1", :arg2 => "arg2"}, :predicate => predicate}], results)
  end

  class AnotherTestPluginWithCustomValidators < ::Proxy::Plugin
    validate :setting, :non_existent => true
  end
  def test_validate_runtime_config_raises_exception_on_unknown_validator
    loader = ::Proxy::DefaultModuleLoader.new(AnotherTestPluginWithCustomValidators, nil)
    assert_raises(Exception) { loader.validate_settings(AnotherTestPluginWithCustomValidators, :setting => "value") }
  end

  class TestDIWirings
    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :testing, Object
    end
  end
  class TestPluginWithCustomWirings < ::Proxy::Plugin
    load_dependency_injection_wirings TestDIWirings
  end
  def test_default_module_initializer_uses_di_wirings
    di_container = ::Proxy::DependencyInjection::Container.new
    loader = ::Proxy::DefaultModuleLoader.new(TestPluginWithCustomWirings, di_container)
    loader.configure_plugin

    assert di_container.get_dependency(:testing).instance_of?(Object)
  end

  class TestService
    def started?
      !!@started
    end

    def start
      @started = true
    end
  end
  class TestDIWiringsWithService
    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.singleton_dependency :testing, TestService
    end
  end
  class AnotherTestPluginWithCustomWirings < ::Proxy::Plugin
    load_dependency_injection_wirings TestDIWiringsWithService
    start_services :testing
  end
  def test_default_module_initializer_starts_services
    di_container = ::Proxy::DependencyInjection::Container.new
    loader = ::Proxy::DefaultModuleLoader.new(AnotherTestPluginWithCustomWirings, di_container)
    loader.configure_plugin

    assert di_container.get_dependency(:testing).started?
  end

  class TestPluginWithAfterActivationBlock < ::Proxy::Plugin
    def self.called_after_activation_block
      @after_activation_called = true
    end

    def self.called_after_activation_block?
      !!@after_activation_called
    end
    after_activation do
      called_after_activation_block
    end
  end
  def test_legacy_module_initializer_calls_after_activation_block
    loader = ::Proxy::LegacyModuleLoader.new(TestPluginWithAfterActivationBlock, nil)

    assert !TestPluginWithAfterActivationBlock.called_after_activation_block?
    loader.configure_plugin
    assert TestPluginWithAfterActivationBlock.called_after_activation_block?
  end
end
