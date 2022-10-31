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
    FileReadableValidatorTestPlugin.load_test_settings()
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

class OptionalUrlValidatorTest < Test::Unit::TestCase
  class OptionalUrlValidatorTestPlugin < ::Proxy::Plugin
    default_settings url: 'http://example.com'
  end

  def validator
    ::Proxy::PluginValidators::OptionalUrl.new(OptionalUrlValidatorTestPlugin, 'url', nil, nil)
  end

  def test_required_parameter_with_a_value_passes_validation
    assert validator.validate!(url: 'http://example.com')
  end

  def test_empty_string_treated_as_missing_value
    error = assert_raises ::Proxy::Error::ConfigurationError do
      validator.validate!(url: '')
    end

    assert_match(/expected to contain a url/, error.message)
  end

  def test_without_a_value
    assert validator.validate!(url: nil)
  end

  def test_required_parameter_without_scheme_fails_validation
    error = assert_raises ::Proxy::Error::ConfigurationError do
      validator.validate!(url: 'example.com')
    end

    assert_match(/missing a scheme/, error.message)
  end
end

class BooleanValidatorTest < Test::Unit::TestCase
  class BooleanValidatorTestPlugin < ::Proxy::Plugin
    default_settings :a_settting => true
  end

  def test_required_parameter_with_a_value_passes_validation
    assert ::Proxy::PluginValidators::Boolean.new(BooleanValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => true)
  end

  def test_empty_string_treated_as_missing_value
    error = assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Boolean.new(BooleanValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => '')
    end

    assert_match(%r{expected to be true/false}, error.message)
  end

  def test_required_parameter_without_a_value_fails_validation
    error = assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Boolean.new(BooleanValidatorTestPlugin, 'a_setting', nil, nil).validate!(:a_setting => nil)
    end

    assert_match(%r{expected to be true/false}, error.message)
  end

  def test_optional_parameter_without_a_value_fails_validation
    error = assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Boolean.new(BooleanValidatorTestPlugin, 'optional_setting', nil, nil).validate!(:optional_setting => nil)
    end

    assert_match(%r{expected to be true/false}, error.message)
  end
end

class EnumValidatorTest < Test::Unit::TestCase
  class TestPlugin < ::Proxy::Plugin
  end

  def validator
    ::Proxy::PluginValidators::Enum.new(TestPlugin, 'drink', %w[beer whisky], nil)
  end

  def test_first_valid_value_passes_validation
    assert validator.validate!(drink: 'beer')
  end

  def test_second_valid_value_passes_validation
    assert validator.validate!(drink: 'whisky')
  end

  def test_an_invalid_value_fails_validation
    assert_raise_with_message ::Proxy::Error::ConfigurationError, "Parameter 'drink' must be one of beer, whisky" do
      validator.validate!(drink: 'wine')
    end
  end

  def test_empty_string_fails_validation
    assert_raise_with_message ::Proxy::Error::ConfigurationError, "Parameter 'drink' must be one of beer, whisky" do
      validator.validate!(drink: '')
    end
  end

  def test_nil_fails_validation
    assert_raise_with_message ::Proxy::Error::ConfigurationError, "Parameter 'drink' must be one of beer, whisky" do
      validator.validate!(drink: nil)
    end
  end
end
