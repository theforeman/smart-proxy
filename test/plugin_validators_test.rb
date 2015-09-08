require 'test_helper'

class PluginValidatorsTest < Test::Unit::TestCase
  class ValidatorTestPlugin < ::Proxy::Plugin
    default_settings :a_setting => 'some_file'
  end

  def test_file_readable
    File.expects(:readable?).with("some_file").returns(true)
    assert ::Proxy::PluginValidators::FileReadable.new(ValidatorTestPlugin, 'a_setting').validate!
  end

  def test_file_readable_raises_exception_if_file_is_unreadable
    File.expects(:readable?).with("some_file").returns(false)
    assert_raises ::Proxy::Error::ConfigurationError do
      ::Proxy::PluginValidators::FileReadable.new(ValidatorTestPlugin, 'a_setting').validate!
    end
  end
end
