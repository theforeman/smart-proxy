require 'test_helper'
require 'puppet_proxy/dependency_injection/container'
require 'puppet_proxy/environment'
require 'puppet_proxy/puppet_config_environments_retriever'

class PuppetConfigurationForTesting
  attr_accessor :data
  def get; data; end
end

class PuppetConfigEnvironmentsRetrieverTest < Test::Unit::TestCase
  def setup
    @puppet_configuration = PuppetConfigurationForTesting.new
    @retriever =  Proxy::Puppet::PuppetConfigEnvironmentsRetriever.new
    @retriever.puppet_configuration = @puppet_configuration
  end

  def test_single_static_env
    @puppet_configuration.data = {
        :main => {},
        :production => { :modulepath =>'./test/fixtures/environments/prod' }
    }

    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['production']
  end

  def test_master_is_remapped_to_production_when_solo
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath =>'./test/fixtures/environments/prod' }
    }

    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['production']
  end

  def test_multiple_static_env
    @puppet_configuration.data = {
        :main => {},
        :production  => { :modulepath =>'./test/fixtures/environments/prod' },
        :development => { :modulepath =>'./test/fixtures/environments/dev' }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['development', 'production'])
  end

  def test_multiple_modulepath_in_single_env_loads_all_classes
    @puppet_configuration.data = {
        :main => {},
        :production  => { :modulepath =>'./test/fixtures/environments/dev:./test/fixtures/environments/prod' },
    }
    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['production']
  end

  def test_single_modulepath_in_single_env_with_dynamic_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath =>'./test/fixtures/environments/$environment/' }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['dev','prod'])
  end

  def test_multiple_modulepath_in_single_env_with_multiple_dynamic_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath =>'./test/fixtures/multi_module/$environment/modules1:./test/fixtures/multi_module/$environment/modules2' }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['dev','prod'])
  end

  def test_multiple_modulepath_in_single_env_with_multiple_dynamic_path_and_static_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath =>'./test/fixtures/environments/prod:./test/fixtures/multi_module/$environment/modules1:./test/fixtures/multi_module/$environment/modules2' }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['master','dev','prod'])
  end

  def test_multiple_modulepath_in_single_env_with_dynamic_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath =>'./test/fixtures/environments/$environment:./test/fixtures/modules_include' }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['dev', 'prod', 'master'])
  end

  def test_multiple_modulepath_in_single_env_with_broken_entry
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath =>'./no/such/$environment/modules:./test/fixtures/environments/prod' }
    }
    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['master']
  end
end
