require 'test_helper'

class PuppetEnvironmentTest < Test::Unit::TestCase

  def test_puppet_class_should_be_an_opject
    klass = Proxy::Puppet::Environment.new :name => "production", :paths => ["/etc/puppet/env/production"]
    assert_kind_of Proxy::Puppet::Environment, klass
  end

  def test_should_provide_puppet_envs
    env = Proxy::Puppet::Environment.send(:puppet_environments)
#    assert env.keys.include?(:production)
  end

  def test_should_provide_env_objects
    environments = mock_puppet_env

    assert_kind_of Array, environments

    env = environments.first
    assert_kind_of Proxy::Puppet::Environment, env
  end

  def test_an_env_should_have_puppet_classes
    env = mock_puppet_env.first
    assert_respond_to env, :classes
    assert_kind_of Array, env.classes
    Puppet::Node::Environment.clear
    assert_kind_of Proxy::Puppet::PuppetClass, env.classes.first
  end

  private

  def mock_puppet_env
    Proxy::Puppet::Environment.stubs(:puppet_environments).returns({:production => "/home/olevy/git/puppet-repos/modules"})
    Proxy::Puppet::Environment.all
  end
end
