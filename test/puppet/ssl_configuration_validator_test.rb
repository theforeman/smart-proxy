require 'test_helper'
require 'puppet_proxy/puppet'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/ssl_configuration_validator'

class SslConfigurationValidatorForTesting < ::Proxy::Puppet::SslConfigurationValidator
  attr_accessor :environments_retriever, :certname
end

class SslConfigurationValidatorTest < Test::Unit::TestCase
  def setup
    @ssl_config_validator = SslConfigurationValidatorForTesting.new
    @ssl_config_validator.environments_retriever = :api_v2
  end

  def test_should_fail_when_ssl_key_is_not_readable
    Proxy::Puppet::Plugin.load_test_settings(
        :puppet_ssl_ca => '../fixtures/authentication/puppet_ca.pem',
        :puppet_ssl_cert => '../fixtures/authentication/foreman.example.com.cert',
        :puppet_ssl_key => 'non_existent_key')

    assert_raises ::Proxy::Error::ConfigurationError do
      @ssl_config_validator.validate_ssl_paths!
    end
  end

  def test_should_fail_when_ssl_cert_is_not_readable
    Proxy::Puppet::Plugin.load_test_settings(
        :puppet_ssl_ca => '../fixtures/authentication/puppet_ca.pem',
        :puppet_ssl_cert => 'non_existent_cert',
        :puppet_ssl_key => '../fixtures/authentication/foreman.example.com.key')

    assert_raises ::Proxy::Error::ConfigurationError do
      @ssl_config_validator.validate_ssl_paths!
    end

  end

  def test_should_fail_when_ca_cert_is_not_readable
    Proxy::Puppet::Plugin.load_test_settings(
        :puppet_ssl_ca => 'non_existent_ca_cert',
        :puppet_ssl_cert => '../fixtures/authentication/foreman.example.com.cert',
        :puppet_ssl_key => '../fixtures/authentication/foreman.example.com.key')

    assert_raises ::Proxy::Error::ConfigurationError do
      @ssl_config_validator.validate_ssl_paths!
    end
  end

  def test_should_pass_if_config_file_environments_are_used
    @ssl_config_validator.environments_retriever = :config_file
    assert @ssl_config_validator.validate_ssl_paths!
  end

  def test_should_pass_if_ssl_files_are_readable
    Proxy::Puppet::Plugin.load_test_settings(
        :puppet_ssl_ca => 'test/fixtures/authentication/puppet_ca.pem',
        :puppet_ssl_cert => 'test/fixtures/authentication/foreman.example.com.cert',
        :puppet_ssl_key => 'test/fixtures/authentication/foreman.example.com.key')

    assert @ssl_config_validator.validate_ssl_paths!
  end

  def test_default_ssl_cert_path
    @ssl_config_validator.certname = 'test'
    assert_equal '/var/lib/puppet/ssl/certs/test.pem', @ssl_config_validator.ssl_cert
  end

  def test_default_ssl_key_path
    @ssl_config_validator.certname = 'test'
    assert_equal '/var/lib/puppet/ssl/private_keys/test.pem', @ssl_config_validator.ssl_key
  end
end
