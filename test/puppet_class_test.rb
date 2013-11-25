require 'test/test_helper'

class PuppetClassTest < Test::Unit::TestCase

  def test_should_have_a_logger
    assert_respond_to Proxy::Puppet, :logger
  end

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
end
