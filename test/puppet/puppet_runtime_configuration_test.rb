require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/runtime_configuration'

class PuppetRuntimeConfigurationTest < Test::Unit::TestCase
  class PuppetRuntimeConfigurationForTesting
    include Proxy::Puppet::RuntimeConfiguration
    attr_accessor :puppet_configuration
  end

  def setup
    @configuration = PuppetRuntimeConfigurationForTesting.new
  end

  def teardown
    Proxy::Puppet::Plugin.load_test_settings(:use_cache => false)
  end

  def test_should_use_environment_api_with_environmentpath_set_main
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5")
    @configuration.puppet_configuration = { :main => {:environmentpath => '/etc' }}
    assert_equal :api_v2, @configuration.environments_retriever
  end

  def test_should_use_environment_api_with_environmentpath_set_master
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5")
    @configuration.puppet_configuration = { :master => {:environmentpath => '/etc'}}
    assert_equal :api_v2, @configuration.environments_retriever
  end

  def test_should_not_use_environment_api_with_no_environmentpath
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5")
    @configuration.puppet_configuration = {}
    assert_equal :config_file, @configuration.environments_retriever
  end

  def test_should_not_use_environment_api_when_override_is_set_to_false
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5", :puppet_use_environment_api => false)
    @configuration.puppet_configuration = { :main => {:environmentpath => '/etc' }}

    assert_equal :config_file, @configuration.environments_retriever
  end

  def test_should_use_environment_api_when_override_is_set_to_true
    Proxy::Puppet::Plugin.load_test_settings(:puppet_use_environment_api => true, :puppet_version => "3.5")
    @configuration.puppet_configuration = {}

    assert_equal :api_v2, @configuration.environments_retriever
  end

  def test_should_use_config_file_environments_for_puppet_older_than_3_2
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.0")
    @configuration.puppet_configuration = {}
    assert_equal :config_file, @configuration.environments_retriever
  end

  def test_should_use_api_v3_for_environments_under_puppet_4
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => '4.0')
    assert_equal :api_v3, @configuration.environments_retriever
  end

  def test_should_use_api_v3_for_classes_under_puppet_4
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => '4.0')
    assert_equal :api_v3, @configuration.classes_retriever
  end

  def test_should_use_future_parser_if_enabled_in_main_config
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5", :use_cache => false)
    @configuration.puppet_configuration = { :main => {:parser => 'future' }}
    assert_equal :future_parser, @configuration.classes_retriever
  end

  def test_should_use_caching_future_parser_if_enabled_in_main_config
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5", :use_cache => true)
    @configuration.puppet_configuration = { :main => {:parser => 'future' }}
    assert_equal :cached_future_parser, @configuration.classes_retriever
  end

  def test_should_use_future_parser_if_enabled_in_master_config
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5", :use_cache => false)
    @configuration.puppet_configuration = { :master => {:parser => 'future' }}
    assert_equal :future_parser, @configuration.classes_retriever
  end

  def test_should_use_legacy_parser_otherwise
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5", :use_cache => false)
    @configuration.puppet_configuration = {}
    assert_equal :legacy_parser, @configuration.classes_retriever
  end

  def test_should_use_caching_legacy_parser
    Proxy::Puppet::Plugin.load_test_settings(:puppet_version => "3.5", :use_cache => true)
    @configuration.puppet_configuration = {}
    assert_equal :cached_legacy_parser, @configuration.classes_retriever
  end
end
