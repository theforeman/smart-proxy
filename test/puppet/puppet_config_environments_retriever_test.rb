require 'test_helper'
require 'puppet_proxy_common/environment'
require 'puppet_proxy_common/environments_retriever_base'
require 'puppet_proxy_common/errors'
require 'puppet_proxy_legacy/puppet_config_environments_retriever'

class PuppetConfigurationForTesting
  attr_accessor :data
  def get; data; end
end

class PuppetConfigEnvironmentsRetrieverTest < Test::Unit::TestCase
  def setup
    @puppet_configuration = PuppetConfigurationForTesting.new
    @retriever =  Proxy::PuppetLegacy::PuppetConfigEnvironmentsRetriever.new(@puppet_configuration, "/etc/puppet/puppet.conf")
  end

  def test_single_static_env
    @puppet_configuration.data = {
        :main => {}, :master => {},
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
        :main => {}, :master => {},
        :production  => { :modulepath => module_path('environments/prod') },
        :development => { :modulepath => module_path('environments/dev') }
    }
    env = @retriever.all
    assert_equal Set.new(env.map { |e| e.name }), Set.new(['development', 'production'])
  end

  def test_multiple_modulepath_in_single_env_loads_all_classes
    @puppet_configuration.data = {
        :main => {}, :master => {},
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

  def test_missing_main_section_in_puppet_configuration_raises_exception
    @puppet_configuration.data = {
        :master => {}
    }
    assert_raise(Exception) { @retriever.all }
  end

  def test_missing_master_section_in_puppet_configuration_raises_exception
    @puppet_configuration.data = {
        :main => {}
    }
    assert_raise(Exception) { @retriever.all }
  end

  def test_get_environment
    @puppet_configuration.data = {
        :main => {}, :master => {},
        :production => { :modulepath => module_path('environments/prod') }
    }

    env = @retriever.get('production')
    assert_equal 'production', env.name
  end

  def test_get_environment_raises_exception_if_environment_not_found
    @puppet_configuration.data = {
        :master => {}, :main => {}
    }
    assert_raise(Proxy::Puppet::EnvironmentNotFound) { @retriever.get('non_existent') }
  end

  def module_path(*relative_path)
    paths = relative_path.map { |path| File.expand_path(path, File.expand_path('../fixtures', __FILE__)) }
    paths.size < 2 ? paths.first : paths.join(':')
  end
end
