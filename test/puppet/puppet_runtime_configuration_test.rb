require 'test_helper'
require 'puppet/puppet_test_helper'
require 'puppet_proxy/runtime_configuration'

class PuppetRuntimeConfigurationForTesting
  include Proxy::Puppet::RuntimeConfiguration
  attr_accessor :puppet_configuration
  attr_accessor :puppet_version
end

class PuppetRuntimeConfigurationTest < Test::Unit::TestCase
  def setup
    @configuration = PuppetRuntimeConfigurationForTesting.new
  end

  def test_should_use_environment_api_with_environmentpath_set_main
    @configuration.puppet_version = "3.5"
    @configuration.puppet_configuration = { :main => {:environmentpath => '/etc' }}
    assert_equal :api_v2, @configuration.environments_retriever
  end

  def test_should_use_environment_api_with_environmentpath_set_master
    @configuration.puppet_version = "3.5"
    @configuration.puppet_configuration = { :master => {:environmentpath => '/etc'}}
    assert_equal :api_v2, @configuration.environments_retriever
  end

  def test_should_not_use_environment_api_with_no_environmentpath
    @configuration.puppet_version = "3.5"
    @configuration.puppet_configuration = {}
    assert_equal :config_file, @configuration.environments_retriever
  end

  def test_should_not_use_environment_api_when_override_is_set_to_false
    Proxy::Puppet::Plugin.load_test_settings(:puppet_use_environment_api => false)
    @configuration.puppet_version = "3.5"
    @configuration.puppet_configuration = { :main => {:environmentpath => '/etc' }}

    assert_equal :config_file, @configuration.environments_retriever
  end

  def test_should_use_environment_api_when_override_is_set_to_true
    Proxy::Puppet::Plugin.load_test_settings(:puppet_use_environment_api => true)
    @configuration.puppet_version = "3.5"
    @configuration.puppet_configuration = {}

    assert_equal :api_v2, @configuration.environments_retriever
  end

  def test_should_use_config_file_environments_for_puppet_older_than_3_2
    @configuration.puppet_version = "3.0"
    @configuration.puppet_configuration = {}
    assert_equal :config_file, @configuration.environments_retriever
  end

  def test_should_use_api_v3_for_puppet_4
    @configuration.puppet_version = "4.0"
    @configuration.puppet_configuration = {}
    assert_equal :api_v3, @configuration.environments_retriever
  end

  def test_should_use_future_parser_for_puppet_4
    @configuration.puppet_version = "4.0"
    assert_equal :future_parser, @configuration.puppet_parser
  end

  def test_should_use_future_parser_if_enabled_in_main_config
    @configuration.puppet_configuration = { :main => {:parser => 'future' }}
    assert_equal :future_parser, @configuration.puppet_parser
  end

  def test_should_use_future_parser_if_enabled_in_master_config
    @configuration.puppet_configuration = { :master => {:parser => 'future' }}
    assert_equal :future_parser, @configuration.puppet_parser
  end

  def test_should_use_legacy_parser_otherwise
    @configuration.puppet_version = "3.5"
    @configuration.puppet_configuration = {}
    assert_equal :legacy_parser, @configuration.puppet_parser
  end
end
