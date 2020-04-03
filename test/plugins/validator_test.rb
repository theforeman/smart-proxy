require 'test_helper'

class BaseValidatorTest < Test::Unit::TestCase
  class TestValidator < ::Proxy::PluginValidators::Base
    attr_reader :validate_called

    def validate!(settings)
      @validate_called = true
    end
  end

  class TestPlugin < ::Proxy::Plugin
    default_settings :setting_a => 'a_value'
  end

  def test_required_setting_is_true_for_settings_with_default_values
    validator = TestValidator.new(TestPlugin, 'setting_a', nil, nil)
    assert validator.required_setting?
  end

  def test_required_setting_is_false_for_settings_without_default_values
    validator = TestValidator.new(TestPlugin, 'setting_b', nil, nil)
    assert !validator.required_setting?
  end

  def test_validate_is_called_if_predicate_evaluates_to_true
    validator = TestValidator.new(TestPlugin, 'setting_a', nil, ->(settings) { settings[:should_validate] == true })
    validator.evaluate_predicate_and_validate!(:should_validate => true)
    assert validator.validate_called
  end

  def test_validate_is_not_called_if_predicate_evaluates_to_false
    validator = TestValidator.new(TestPlugin, 'setting_a', nil, ->(settings) { settings[:should_validate] == true })
    validator.evaluate_predicate_and_validate!(:should_validate => false)
    assert !validator.validate_called
  end
end

class FileReadableValidatorTest < Test::Unit::TestCase
  class FileReadableValidatorTestPlugin < ::Proxy::Plugin
    default_settings :a_setting => 'some_file'
  end

  def test_file_readable_returns_true_for_optional_undefined_settings
    FileReadableValidatorTestPlugin.load_test_settings({})
    assert ::Proxy::PluginValidators::FileReadable.new(FileReadableValidatorTestPlugin, 'optional_setting', nil, nil).validate!({})
  end

  def test_file_readable_for_optional_defined_setting
    File.expects(:readable?).with("other_file").returns(true)
    assert ::Proxy::PluginValidators::FileReadable.new(FileReadableValidatorTestPlugin, 'optional_setting', nil, nil).validate!(:optional_setting => 'other_file')
  end

  def test_file_readable_for_required_setting
    File.expects(:readable?).with("some_file").returns(true)
    assert ::Proxy::PluginValidators::FileReadable.new(FileReadableValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => 'some_file')
  end

  def test_file_readable_raises_exception_if_file_is_unreadable
    File.expects(:readable?).with("some_file").returns(false)
    assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::FileReadable.new(FileReadableValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => 'some_file')
    end
  end
end

class PresenceValidatorTest < Test::Unit::TestCase
  class PresenceValidatorTestPlugin < ::Proxy::Plugin
    default_settings :a_setting => 'some_file'
  end

  def test_required_parameter_with_a_value_passes_validation
    assert ::Proxy::PluginValidators::Presence.new(PresenceValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => 'some_file')
  end

  def test_empty_string_treated_as_missing_value
    assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Presence.new(PresenceValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => '')
    end
  end

  def test_required_parameter_without_a_value_fails_validation
    assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Presence.new(PresenceValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => nil)
    end
  end

  def test_optional_parameter_without_a_value_fails_validation
    assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Presence.new(PresenceValidatorTestPlugin, 'optional_setting', nil, nil).validate!(:optional_setting => nil)
    end
  end
end

class UrlValidatorTest < Test::Unit::TestCase
  class UrlValidatorTestPlugin < ::Proxy::Plugin
    default_settings :a_setting => 'http://example.com'
  end

  def test_required_parameter_with_a_value_passes_validation
    assert ::Proxy::PluginValidators::Url.new(UrlValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => 'http://example.com')
  end

  def test_empty_string_treated_as_missing_value
    error = assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Url.new(UrlValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => '')
    end

    assert_match(/expected to contain a url/, error.message)
  end

  def test_required_parameter_without_a_value_fails_validation
    error = assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Url.new(UrlValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => nil)
    end

    assert_match(/expected to contain a url/, error.message)
  end

  def test_required_parameter_without_scheme_fails_validation
    error = assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Url.new(UrlValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => 'example.com')
    end

    assert_match(/missing a scheme/, error.message)
  end

  def test_optional_parameter_without_a_value_fails_validation
    error = assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Url.new(UrlValidatorTestPlugin, 'optional_setting', nil, nil).validate!(:optional_setting => nil)
    end

    assert_match(/expected to contain a url/, error.message)
  end
end
