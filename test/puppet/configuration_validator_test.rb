require 'test_helper'
require 'puppet_proxy/runtime_configuration'
require 'puppet_proxy/configuration_validator'

class ConfigurationValidatorForTesting < ::Proxy::Puppet::ConfigurationValidator
  attr_accessor :environments_retriever, :classes_retriever
end

class ConfigurationValidatorTest < Test::Unit::TestCase
  def setup
    @ssl_config_validator = ConfigurationValidatorForTesting.new({})
    @ssl_config_validator.environments_retriever = :api_v2
  end

  def test_validate_passes_correct_parameters
    validator = ConfigurationValidatorForTesting.new(OpenStruct.new(
        :puppet_url => 'http://puppet_url', :puppet_conf => 'puppet_conf_path',
        :puppet_ssl_ca => 'ca_path', :puppet_ssl_cert => 'ssl_cert_path', :puppet_ssl_key => 'ssl_key_path'))

    validator.expects(:validate_puppet_url!).with('http://puppet_url')
    validator.expects(:validate_puppet_conf!).with('puppet_conf_path')
    validator.expects(:validate_ssl_paths!).with('ca_path', 'ssl_cert_path', 'ssl_key_path')

    validator.validate!
  end

  def test_should_fail_when_ssl_key_is_not_readable
    assert_raises ::Proxy::Error::ConfigurationError do
      @ssl_config_validator.validate_ssl_paths!(certs_path('puppet_ca.pem'), certs_path('foreman.example.com.cert'), 'non_existent_key')
    end
  end

  def test_should_fail_when_ssl_cert_is_not_readable
    assert_raises ::Proxy::Error::ConfigurationError do
      @ssl_config_validator.validate_ssl_paths!(certs_path('puppet_ca.pem'), 'non_existent_cert', certs_path('foreman.example.com.key'))
    end

  end

  def test_should_fail_when_ca_cert_is_not_readable
    assert_raises ::Proxy::Error::ConfigurationError do
      @ssl_config_validator.validate_ssl_paths!('non_existent_ca_cert', certs_path('foreman.example.com.cert'), certs_path('foreman.example.com.key'))
    end
  end

  def test_should_pass_if_config_file_environments_are_used
    @ssl_config_validator.environments_retriever = :config_file
    assert @ssl_config_validator.validate_ssl_paths!(nil, nil, nil)
  end

  def test_should_pass_if_ssl_files_are_readable
    assert @ssl_config_validator.validate_ssl_paths!(certs_path('puppet_ca.pem'), certs_path('foreman.example.com.cert'), certs_path('foreman.example.com.key'))
  end

  def test_validate_puppet_url_returns_true_if_config_file_used_for_environments_api
    @ssl_config_validator.environments_retriever = :config_file
    assert @ssl_config_validator.validate_puppet_url!("invalid_url")
  end

  def test_validate_puppet_url_returns_true_if_it_is_present_and_valid
    @ssl_config_validator.environments_retriever = :api_v3
    assert @ssl_config_validator.validate_puppet_url!("http://localhost")
  end

  def test_validate_puppet_url_raises_exception_if_url_is_invalid
    @ssl_config_validator.environments_retriever = :api_v3
    assert_raises(Proxy::Error::ConfigurationError) { @ssl_config_validator.validate_puppet_url!("%uABC") }
  end

  def test_validate_puppet_conf_returns_true_if_puppet_api_are_used
    @ssl_config_validator.classes_retriever = :api_v3
    assert @ssl_config_validator.validate_puppet_conf!("non-existent")
  end

  def test_validate_puppet_conf_returns_true_if_file_is_readable
    @ssl_config_validator.classes_retriever = :future_parser
    assert @ssl_config_validator.validate_puppet_conf!(certs_path('puppet_ca.pem'))
  end

  def test_validate_puppet_conf_raises_exception_if_file_does_not_exist
    @ssl_config_validator.environments_retriever = :future_parser
    assert_raises(Proxy::Error::ConfigurationError) { @ssl_config_validator.validate_puppet_conf!("non-existent") }
  end

  def certs_path(relative_path)
    File.expand_path(relative_path, File.expand_path('../fixtures/authentication', __FILE__))
  end
end
