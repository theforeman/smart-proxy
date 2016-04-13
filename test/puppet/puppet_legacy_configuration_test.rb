require 'test_helper'
require 'puppet_proxy_legacy/puppet_proxy_legacy'

class PuppetLegacyProgrammableSettingsTest < Test::Unit::TestCase
  def setup
    @configuration = ::Proxy::PuppetLegacy::PluginConfiguration.new
  end

  def test_use_future_parser_when_main_parser_is_set
    assert @configuration.use_future_parser?(:main => {:parser => "future"})
  end

  def test_use_future_parser_when_master_parser_is_set
    assert @configuration.use_future_parser?(:master => {:parser => "future"})
  end

  def test_use_future_parser_when_main_and_master_are_missing
    assert !@configuration.use_future_parser?({})
  end

  def test_use_environment_api_when_main_environmentpath_is_set
    assert !@configuration.use_environment_api?(:main => {:environmentpath => ["a/path"]})
  end

  def test_use_environment_api_when_master_environmentpath_is_set
    assert !@configuration.use_environment_api?(:master => {:environmentpath => ["a/path"]})
  end

  def test_use_environment_api_when_main_and_master_are_missing
    assert @configuration.use_environment_api?({})
  end

  def test_use_environment_api_when_no_environment_paths_are_present
    configuration = LegacyProviderConfigurationForTesting.new({})
    assert configuration.use_environment_api?(:main => {}, :master => {})
  end

  def test_puppet_conf_exists_is_used_in_load_programmable_settings_call
    @configuration.expects(:puppet_conf_exists?).with("a/path")
    @configuration.stubs(:load_puppet_configuration).returns({})
    @configuration.load_programmable_settings(:puppet_conf => "a/path")
  end

  class LegacyProviderConfigurationForTesting < ::Proxy::PuppetLegacy::PluginConfiguration
    def initialize(puppet_config)
      @config = puppet_config
    end

    def puppet_conf_exists?(a_path); end
  end

  def test_load_puppet_configuration_is_used_in_load_programmable_settings_call
    configuration = LegacyProviderConfigurationForTesting.new({})
    configuration.stubs(:load_puppet_configuration).with("a/path").returns({})
    configuration.load_programmable_settings(:puppet_conf => "a/path")
  end

  def test_load_programmable_settings_sets_cached_future_parser
    configuration = LegacyProviderConfigurationForTesting.new(:main => {:parser => "future"})
    assert_equal :cached_future_parser, configuration.load_programmable_settings(:use_cache => true)[:classes_retriever]
  end

  def test_load_programmable_settings_sets_future_parser
    configuration = LegacyProviderConfigurationForTesting.new(:main => {:parser => "future"})
    assert_equal :future_parser, configuration.load_programmable_settings(:use_cache => false)[:classes_retriever]
  end

  def test_load_programmable_settings_sets_cached_legacy_parser
    configuration = LegacyProviderConfigurationForTesting.new({})
    assert_equal :cached_legacy_parser, configuration.load_programmable_settings(:use_cache => true)[:classes_retriever]
  end

  def test_load_programmable_settings_sets_legacy_parser
    configuration = LegacyProviderConfigurationForTesting.new({})
    assert_equal :legacy_parser, configuration.load_programmable_settings(:use_cache => false)[:classes_retriever]
  end

  def test_load_programmable_settings_sets_config_file_for_environments_retriever_for_puppet_before_3_2
    configuration = LegacyProviderConfigurationForTesting.new({})
    assert_equal :config_file, configuration.load_programmable_settings(:puppet_version => "3.1")[:environments_retriever]
  end

  def test_load_programmable_settings_sets_config_file_for_environments_retriever_when_puppet_use_environment_api_is_false
    configuration = LegacyProviderConfigurationForTesting.new({})
    assert_equal :config_file, configuration.load_programmable_settings(:puppet_version => "3.2", :use_environment_api => false)[:environments_retriever]
  end

  def test_load_programmable_settings_sets_api_v2_for_environments_retriever_when_puppet_use_environment_api_is_true
    configuration = LegacyProviderConfigurationForTesting.new({})
    assert_equal :api_v2, configuration.load_programmable_settings(:puppet_version => "3.2", :use_environment_api => true)[:environments_retriever]
  end

  def test_load_programmable_settings_sets_api_v2_for_environments_retriever_whithout_puppet_use_environment_api_and_environmentpath_missing
    configuration = LegacyProviderConfigurationForTesting.new(:master => {}, :main => {})
    assert_equal :api_v2, configuration.load_programmable_settings(:puppet_version => "3.2")[:environments_retriever]
  end

  def test_load_programmable_settings_sets_api_v2_for_environments_retriever_whithout_puppet_use_environment_api_and_environmentpath_present
    configuration = LegacyProviderConfigurationForTesting.new(:master => {}, :main => {:environmentpath => ["a/path"]})
    assert_equal :config_file, configuration.load_programmable_settings(:puppet_version => "3.2")[:environments_retriever]
  end
end

class PuppetLegacyDefaultSettingsTest < Test::Unit::TestCase
  def test_default_settings
    Proxy::PuppetLegacy::Plugin.load_test_settings({})
    assert_equal '/var/lib/puppet/ssl/certs/ca.pem', Proxy::PuppetLegacy::Plugin.settings.puppet_ssl_ca
    assert_equal '/etc/puppet/puppet.conf', Proxy::PuppetLegacy::Plugin.settings.puppet_conf
    assert Proxy::PuppetLegacy::Plugin.settings.use_cache
  end
end

require 'puppet_proxy_common/environments_retriever_base'
require 'puppet_proxy_legacy/class_scanner_base'
require 'puppet_proxy_legacy/initializer'

class PuppetLegacyDIWiringsTest < Test::Unit::TestCase
  def setup
    @configuration = ::Proxy::PuppetLegacy::PluginConfiguration.new
    @container = ::Proxy::DependencyInjection::Container.new
  end

  def test_apiv2_environments_retriever_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :environments_retriever => :api_v2,
                                                     :puppet_url => "http://puppet.url",
                                                     :puppet_ssl_ca => "path_to_ca_cert",
                                                     :puppet_ssl_cert => "path_to_ssl_cert",
                                                     :puppet_ssl_key => "path_to_ssl_key")

    assert @container.get_dependency(:environment_retriever_impl).instance_of?(::Proxy::PuppetLegacy::PuppetApiV2EnvironmentsRetriever)
    assert_equal "http://puppet.url", @container.get_dependency(:environment_retriever_impl).puppet_url
    assert_equal "path_to_ca_cert", @container.get_dependency(:environment_retriever_impl).ssl_ca
    assert_equal "path_to_ssl_cert", @container.get_dependency(:environment_retriever_impl).ssl_cert
    assert_equal "path_to_ssl_key", @container.get_dependency(:environment_retriever_impl).ssl_key
  end

  def test_puppet_configuration_wiring
    @configuration.load_dependency_injection_wirings(@container, :environments_retriever => :config_file,
                                                     :puppet_conf => "path_to_puppet_conf")

    assert @container.get_dependency(:puppet_configuration).instance_of?(Proxy::PuppetLegacy::ConfigReader)
  end

  def test_config_environments_retriever_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :environments_retriever => :config_file,
                                                     :puppet_conf => "path_to_puppet_conf")

    assert @container.get_dependency(:environment_retriever_impl).instance_of?(::Proxy::PuppetLegacy::PuppetConfigEnvironmentsRetriever)
    assert_not_nil @container.get_dependency(:environment_retriever_impl).puppet_configuration
    assert_equal "path_to_puppet_conf", @container.get_dependency(:environment_retriever_impl).puppet_config_file_path
  end

  def test_puppet_initializer_wiring
    @configuration.load_dependency_injection_wirings(@container, :puppet_conf => "path_to_puppet_conf")
    assert @container.get_dependency(:puppet_initializer).instance_of?(Proxy::PuppetLegacy::Initializer)
  end

  def test_cached_future_parser_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :classes_retriever => :cached_future_parser)

    assert @container.get_dependency(:class_retriever_impl).instance_of?(::Proxy::PuppetLegacy::PuppetCache)
    assert_not_nil @container.get_dependency(:class_retriever_impl).environments_retriever
    assert @container.get_dependency(:class_retriever_impl).class_parser.instance_of?(::Proxy::PuppetLegacy::ClassScannerEParser)
  end

  def test_cached_legacy_parser_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :classes_retriever => :cached_legacy_parser)

    assert @container.get_dependency(:class_retriever_impl).instance_of?(::Proxy::PuppetLegacy::PuppetCache)
    assert_not_nil @container.get_dependency(:class_retriever_impl).environments_retriever
    assert @container.get_dependency(:class_retriever_impl).class_parser.instance_of?(::Proxy::PuppetLegacy::ClassScanner)
  end

  def test_future_parser_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :classes_retriever => :future_parser)

    assert @container.get_dependency(:class_retriever_impl).instance_of?(::Proxy::PuppetLegacy::ClassScannerEParser)
    assert_not_nil @container.get_dependency(:class_retriever_impl).environments_retriever
    assert_not_nil @container.get_dependency(:class_retriever_impl).puppet_initializer
  end

  def test_legacy_parser_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :classes_retriever => :legacy_parser)

    assert @container.get_dependency(:class_retriever_impl).instance_of?(::Proxy::PuppetLegacy::ClassScanner)
    assert_not_nil @container.get_dependency(:class_retriever_impl).environments_retriever
    assert_not_nil @container.get_dependency(:class_retriever_impl).puppet_initializer
  end
end
