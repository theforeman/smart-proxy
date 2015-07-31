require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet/testing_class_scanner_factory'

class ClassScannerFactoryTest < Test::Unit::TestCase
  def setup
    ::Proxy::Puppet::ClassScannerFactory.new(false).reset_cache
  end

  def test_should_return_regular_parser
    Proxy::Puppet::Plugin.load_test_settings(:use_cache => false)
    assert_equal ::Proxy::Puppet::ClassScanner, ::Proxy::Puppet::ClassScannerFactory.new(false).scanner
  end

  def test_should_return_future_parser
    Proxy::Puppet::Plugin.load_test_settings(:use_cache => false)
    assert_equal ::Proxy::Puppet::ClassScannerEParser, ::Proxy::Puppet::ClassScannerFactory.new(true).scanner
  end

  def test_should_return_caching_parser
    Proxy::Puppet::Plugin.load_test_settings(:use_cache => true)
    scanner  = ::Proxy::Puppet::ClassScannerFactory.new(false).scanner

    assert_instance_of ::Proxy::Puppet::PuppetCache, scanner
    assert_equal ::Proxy::Puppet::ClassScanner, scanner.class_scanner
  end

  def test_should_return_caching_future_parser
    Proxy::Puppet::Plugin.load_test_settings(:use_cache => true)
    scanner  = ::Proxy::Puppet::ClassScannerFactory.new(true).scanner

    assert scanner.is_a?(::Proxy::Puppet::PuppetCache)
    assert_equal ::Proxy::Puppet::ClassScannerEParser, scanner.class_scanner
  end

  def test_should_use_shared_cache_by_default
    Proxy::Puppet::Plugin.load_test_settings(:use_cache => true)
    scanner1 = ::Proxy::Puppet::ClassScannerFactory.new(true).scanner
    scanner2 = ::Proxy::Puppet::ClassScannerFactory.new(true).scanner

    assert_equal scanner1, scanner2
  end
end
