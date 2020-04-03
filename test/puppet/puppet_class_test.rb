require 'test_helper'
require 'puppet_proxy/puppet_class'

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

  def test_json_serialization
    clazz = Proxy::Puppet::PuppetClass.new(
      "foreman_proxy::install", "namedconf_path" => "${::dns::params::namedconf_path}", "dnsdir" => "${::dns::params::dnsdir}")

    assert clazz.to_json.include?("\"json_class\":\"Proxy::Puppet::PuppetClass\"")
    assert clazz.to_json.include?("\"klass\":\"foreman_proxy::install\"")
    assert clazz.to_json.include?("\"params\":{")
    assert clazz.to_json.include?("\"namedconf_path\":\"${::dns::params::namedconf_path}\"")
    assert clazz.to_json.include?("\"dnsdir\":\"${::dns::params::dnsdir}\"")
  end
end
