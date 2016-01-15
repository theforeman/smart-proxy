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
        :production => { :modulepath => module_path('environments/prod') }
    }

    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['production']
  end

  def test_master_is_remapped_to_production_when_solo
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath => module_path('environments/prod') }
    }

    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['production']
  end

  def test_multiple_static_env
    @puppet_configuration.data = {
        :main => {},
        :production  => { :modulepath => module_path('environments/prod') },
        :development => { :modulepath => module_path('environments/dev') }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['development', 'production'])
  end

  def test_multiple_modulepath_in_single_env_loads_all_classes
    @puppet_configuration.data = {
        :main => {},
        :production  => { :modulepath => module_path('environments/dev', 'environments/prod') },
    }
    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['production']
  end

  def test_single_modulepath_in_single_env_with_dynamic_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath => module_path('environments/$environment/') }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['dev','prod'])
  end

  def test_multiple_modulepath_in_single_env_with_multiple_dynamic_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath => module_path('multi_module/$environment/modules1', 'multi_module/$environment/modules2') }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['dev','prod'])
  end

  def test_multiple_modulepath_in_single_env_with_multiple_dynamic_path_and_static_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath => module_path('environments/prod', 'multi_module/$environment/modules1', 'multi_module/$environment/modules2') }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['master','dev','prod'])
  end

  def test_multiple_modulepath_in_single_env_with_dynamic_path
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath => module_path('environments/$environment', 'modules_include') }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['dev', 'prod', 'master'])
  end

  def test_multiple_modulepath_in_single_env_with_broken_entry
    @puppet_configuration.data = {
        :main => {},
        :master => { :modulepath => module_path('./no/such/$environment/modules', 'environments/prod') }
    }
    env = @retriever.all
    assert_equal env.map { |e| e.name }, ['master']
  end

  def module_path(*relative_path)
    paths = relative_path.map { |path| File.expand_path(path, File.expand_path('../fixtures', __FILE__)) }
    paths.size < 2 ? paths.first : paths.join(':')
  end
end
