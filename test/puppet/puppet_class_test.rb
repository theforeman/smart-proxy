require 'test_helper'
require 'puppet/puppet_class'
require 'puppet/initializer'

class PuppetClassTest < Test::Unit::TestCase
  def test_should_parse_modulename_correctly
    klass = Proxy::Puppet::PuppetClass.new "foreman_proxy::install"
    assert_equal "foreman_proxy", klass.module
    klass = Proxy::Puppet::PuppetClass.new "dummy"
    assert_nil klass.module
    klass = Proxy::Puppet::PuppetClass.new "dummy::klass::nested"
    assert_equal "dummy", klass.module
  end

  def test_should_parse_puppet_class_correctly
    klass = Proxy::Puppet::PuppetClass.new "foreman_proxy::install"
    assert_equal "install", klass.name
    klass = Proxy::Puppet::PuppetClass.new "dummy"
    assert_equal "dummy", klass.name
    klass = Proxy::Puppet::PuppetClass.new "dummy::klass::nested"
    assert_equal "klass::nested", klass.name
  end

  def test_puppet_class_should_be_an_opject
    klass = Proxy::Puppet::PuppetClass.new "foreman_proxy::install"
    assert_kind_of Proxy::Puppet::PuppetClass, klass
  end

  def test_scan_directory_loads_scanner
    Proxy::Puppet::Initializer.expects(:load)
    Proxy::Puppet::ClassScanner.expects(:scan_directory).with('/foo')
    Proxy::Puppet::PuppetClass.scan_directory('/foo', nil)
  end

  def test_scan_directory_loads_eparser_scanner
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    Proxy::Puppet::Initializer.expects(:load)
    Proxy::Puppet::ClassScannerEParser.expects(:scan_directory).with('/foo')
    Proxy::Puppet::PuppetClass.scan_directory('/foo', true)
  end
end
