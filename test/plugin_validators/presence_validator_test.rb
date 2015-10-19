require 'test_helper'

class PresenceValidatorTest < Test::Unit::TestCase
  class PresenceValidatorTestPlugin < ::Proxy::Plugin
    default_settings :a_setting => 'some_file'
  end

  def test_required_parameter_with_a_value_passes_validation
    PresenceValidatorTestPlugin.load_test_settings({})
    assert ::Proxy::PluginValidators::Presence.new(PresenceValidatorTestPlugin, 'a_setting').validate!
  end

  def test_required_parameter_without_a_value_fails_validation
    PresenceValidatorTestPlugin.load_test_settings(:a_setting => nil)
    assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Presence.new(PresenceValidatorTestPlugin, 'a_setting').validate!
    end
  end

  def test_optional_parameter_without_a_value_fails_validation
    PresenceValidatorTestPlugin.load_test_settings(:optional_setting => nil)
    assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::Presence.new(PresenceValidatorTestPlugin, 'optional_setting').validate!
    end
  end
end
