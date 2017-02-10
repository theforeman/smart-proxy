require 'test_helper'
require 'puppet_proxy_puppet_api/puppet_proxy_puppet_api'

class PuppetApiConfigurationTest < Test::Unit::TestCase
  def setup
    @configuration = ::Proxy::PuppetApi::PluginConfiguration.new
  end

  def test_load_programmable_settings_sets_classes_retriever
    assert_equal :apiv3, @configuration.load_programmable_settings({})[:classes_retriever]
  end

  def test_load_programmable_settings_sets_environments_retriever
    assert_equal :apiv3, @configuration.load_programmable_settings({})[:environments_retriever]
  end
end

class PuppetApiDefaultSettingsTest < Test::Unit::TestCase
  def test_default_settings
    Proxy::PuppetApi::Plugin.load_test_settings({})
    assert_equal '/var/lib/puppet/ssl/certs/ca.pem', Proxy::PuppetApi::Plugin.settings.puppet_ssl_ca
    assert_equal 30, Proxy::PuppetApi::Plugin.settings.api_timeout
  end
end

require 'puppet_proxy_common/environments_retriever_base'
require 'puppet_proxy_puppet_api/v3_environments_retriever'
require 'puppet_proxy_puppet_api/v3_classes_retriever'

class PuppetApiDIWiringsTest < Test::Unit::TestCase
  def setup
    @configuration = ::Proxy::PuppetApi::PluginConfiguration.new
    @container = ::Proxy::DependencyInjection::Container.new
  end

  def test_apiv3_environments_retriever_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container,
                                                     :puppet_url => "http://puppet.url",
                                                     :puppet_ssl_ca => "path_to_ca_cert",
                                                     :puppet_ssl_cert => "path_to_ssl_cert",
                                                     :puppet_ssl_key => "path_to_ssl_key")

    assert @container.get_dependency(:environment_retriever_impl).instance_of?(::Proxy::PuppetApi::V3EnvironmentsRetriever)
    assert_equal "http://puppet.url", @container.get_dependency(:environment_retriever_impl).puppet_url
    assert_equal "path_to_ca_cert", @container.get_dependency(:environment_retriever_impl).ssl_ca
    assert_equal "path_to_ssl_cert", @container.get_dependency(:environment_retriever_impl).ssl_cert
    assert_equal "path_to_ssl_key", @container.get_dependency(:environment_retriever_impl).ssl_key
  end

  def test_apiv3_classes_retriever_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container,
                                                     :puppet_url => "http://puppet.url",
                                                     :puppet_ssl_ca => "path_to_ca_cert",
                                                     :puppet_ssl_cert => "path_to_ssl_cert",
                                                     :puppet_ssl_key => "path_to_ssl_key",
                                                     :puppet_version => "4.2")

    assert @container.get_dependency(:class_retriever_impl).instance_of?(::Proxy::PuppetApi::V3ClassesRetriever)
    assert_equal "http://puppet.url", @container.get_dependency(:class_retriever_impl).puppet_url
    assert_equal "path_to_ca_cert", @container.get_dependency(:class_retriever_impl).ssl_ca
    assert_equal "path_to_ssl_cert", @container.get_dependency(:class_retriever_impl).ssl_cert
    assert_equal "path_to_ssl_key", @container.get_dependency(:class_retriever_impl).ssl_key
  end

  def test_environment_classes_retriever_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container,
                                                     :puppet_url => "http://puppet.url",
                                                     :puppet_ssl_ca => "path_to_ca_cert",
                                                     :puppet_ssl_cert => "path_to_ssl_cert",
                                                     :puppet_ssl_key => "path_to_ssl_key",
                                                     :api_timeout => 100,
                                                     :puppet_version => "4.4")

    assert @container.get_dependency(:class_retriever_impl).instance_of?(::Proxy::PuppetApi::V3EnvironmentClassesApiClassesRetriever)
    assert_equal "http://puppet.url", @container.get_dependency(:class_retriever_impl).puppet_url
    assert_equal "path_to_ca_cert", @container.get_dependency(:class_retriever_impl).ssl_ca
    assert_equal "path_to_ssl_cert", @container.get_dependency(:class_retriever_impl).ssl_cert
    assert_equal "path_to_ssl_key", @container.get_dependency(:class_retriever_impl).ssl_key
    assert_equal 100, @container.get_dependency(:class_retriever_impl).api_timeout
  end
end
