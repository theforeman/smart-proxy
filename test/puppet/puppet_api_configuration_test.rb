require 'test_helper'
require 'puppet_proxy/puppet'

class PuppetConfigurationTest < Test::Unit::TestCase
  def setup
    @configuration = ::Proxy::Puppet::ConfigurationLoader.new
  end

  def test_load_programmable_settings_sets_classes_retriever
    assert_equal :apiv3, @configuration.load_programmable_settings({})[:classes_retriever]
  end

  def test_load_programmable_settings_sets_environments_retriever
    assert_equal :apiv3, @configuration.load_programmable_settings({})[:environments_retriever]
  end
end

class PuppetDefaultSettingsTest < Test::Unit::TestCase
  def test_default_settings
    Proxy::Puppet::Plugin.load_test_settings({})
    assert_equal '/etc/puppetlabs/puppet/ssl/certs/ca.pem', Proxy::Puppet::Plugin.settings.puppet_ssl_ca
    assert_equal 30, Proxy::Puppet::Plugin.settings.api_timeout
  end
end

require 'puppet_proxy/apiv3'
require 'puppet_proxy/v3_environments_retriever'
require 'puppet_proxy/v3_environment_classes_api_classes_retriever'

class PuppetDIWiringsTest < Test::Unit::TestCase
  def setup
    @configuration = ::Proxy::Puppet::ConfigurationLoader.new
    @container = ::Proxy::DependencyInjection::Container.new
  end

  def test_apiv3_environments_retriever_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container,
                                                     :puppet_url => "http://puppet.url",
                                                     :puppet_ssl_ca => "path_to_ca_cert",
                                                     :puppet_ssl_cert => "path_to_ssl_cert",
                                                     :puppet_ssl_key => "path_to_ssl_key")

    assert @container.get_dependency(:environment_retriever_impl).instance_of?(::Proxy::Puppet::V3EnvironmentsRetriever)
  end

  def test_environment_classes_retriever_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container,
                                                     :puppet_url => "http://puppet.url",
                                                     :puppet_ssl_ca => "path_to_ca_cert",
                                                     :puppet_ssl_cert => "path_to_ssl_cert",
                                                     :puppet_ssl_key => "path_to_ssl_key",
                                                     :api_timeout => 100)

    assert @container.get_dependency(:class_retriever_impl).instance_of?(::Proxy::Puppet::V3EnvironmentClassesApiClassesRetriever)
    assert_equal "http://puppet.url", @container.get_dependency(:class_retriever_impl).puppet_url
    assert_equal "path_to_ca_cert", @container.get_dependency(:class_retriever_impl).ssl_ca
    assert_equal "path_to_ssl_cert", @container.get_dependency(:class_retriever_impl).ssl_cert
    assert_equal "path_to_ssl_key", @container.get_dependency(:class_retriever_impl).ssl_key
    assert_equal 100, @container.get_dependency(:class_retriever_impl).api_timeout
  end
end
