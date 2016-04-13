require 'test_helper'
require 'ostruct'

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
