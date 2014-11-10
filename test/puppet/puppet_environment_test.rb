require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/environment'

class PuppetEnvironmentTest < Test::Unit::TestCase

  def setup
    Proxy::Puppet::Plugin.load_test_settings(:puppet_conf => './test/fixtures/puppet.conf', :use_cache => false)
  end

  def test_puppet_class_should_be_an_opject
    klass = Proxy::Puppet::Environment.new :name => "production", :paths => ["/etc/puppet/env/production"]
    assert_kind_of Proxy::Puppet::Environment, klass
  end

  def test_should_provide_puppet_envs
    env = Proxy::Puppet::Environment.send(:config_environments, :main => {}, :master => {})
    assert env.keys.include?(:production)
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

  def test_uses_puppet_config
    config_reader = mock('config')
    config_reader.expects(:get).returns(:main => {}, :master => {})
    Proxy::Puppet::Initializer.expects(:load)
    Proxy::Puppet::Initializer.expects(:config).returns('/foo/puppet.conf').at_least_once
    Proxy::Puppet::ConfigReader.expects(:new).with('/foo/puppet.conf').returns(config_reader)
    Proxy::Puppet::Environment.expects(:use_environment_api?).returns(false)
    Proxy::Puppet::Environment.expects(:config_environments).with(:main => {}, :master => {}).returns({})
    Proxy::Puppet::Environment.all
  end

  def test_classes_calls_scan_directory
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns({})
    env = Proxy::Puppet::Environment.new(:name => 'production', :paths => ['/etc/puppet/modules', '/etc/puppet/production'])
    Proxy::Puppet::PuppetClass.expects(:scan_directory).with('/etc/puppet/modules', 'production', nil)
    Proxy::Puppet::PuppetClass.expects(:scan_directory).with('/etc/puppet/production', 'production', nil)
    env.classes
  end

  def test_classes_calls_scan_directory_with_eparser_master
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(:master => {:parser => 'future'})
    env = Proxy::Puppet::Environment.new(:name => 'production', :paths => ['/etc/puppet/modules', '/etc/puppet/production'])
    Proxy::Puppet::PuppetClass.expects(:scan_directory).with('/etc/puppet/modules', 'production', true)
    Proxy::Puppet::PuppetClass.expects(:scan_directory).with('/etc/puppet/production', 'production', true)
    env.classes
  end

  def test_classes_calls_scan_directory_with_eparser_main
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(:main => {:parser => 'future'})
    env = Proxy::Puppet::Environment.new(:name => 'production', :paths => ['/etc/puppet/modules', '/etc/puppet/production'])
    Proxy::Puppet::PuppetClass.expects(:scan_directory).with('/etc/puppet/modules', 'production', true)
    Proxy::Puppet::PuppetClass.expects(:scan_directory).with('/etc/puppet/production', 'production', true)
    env.classes
  end

  def test_single_static_env
    config = {
        :main => {},
        :production => { :modulepath=>'./test/fixtures/environments/prod' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['production']
  end

  def test_master_is_remapped_to_production_when_solo
    config = {
        :main => {},
        :master => { :modulepath=>'./test/fixtures/environments/prod' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['production']
  end

  def test_multiple_static_env
    config = {
        :main => {},
        :production  => { :modulepath=>'./test/fixtures/environments/prod' },
        :development => { :modulepath=>'./test/fixtures/environments/dev' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['development', 'production']
  end

  def test_multiple_modulepath_in_single_env_loads_all_classes
    config = {
        :main => {},
        :production  => { :modulepath=>'./test/fixtures/environments/dev:./test/fixtures/environments/prod' },
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['production']
    assert_array_equal env.first.classes.map { |c| c.name}, ['test','test2']
  end

  def test_single_modulepath_in_single_env_with_dynamic_path
    config = {
        :main => {},
        :master => { :modulepath=>'./test/fixtures/environments/$environment/' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['dev','prod']
    env_class_map = env.map { |e| [e.name, e.classes.map { |c| c.name }].flatten }
    assert_array_equal env_class_map, [["prod", "test"], ["dev", "test2"]]
  end

  def test_multiple_modulepath_in_single_env_with_multiple_dynamic_path
    config = {
        :main => {},
        :master => { :modulepath=>'./test/fixtures/multi_module/$environment/modules1:./test/fixtures/multi_module/$environment/modules2' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['dev','prod']
    env_class_map = env.map { |e| [e.name, e.classes.map { |c| c.name }].flatten }
    assert_array_equal env_class_map, [["prod", "test1", "test2"], ["dev", "test3", "test4"]]
  end

  def test_multiple_modulepath_in_single_env_with_multiple_dynamic_path_and_static_path
    config = {
        :main => {},
        :master => { :modulepath=>'./test/fixtures/environments/prod:./test/fixtures/multi_module/$environment/modules1:./test/fixtures/multi_module/$environment/modules2' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['master','dev','prod']
    env_class_map = env.map { |e| [e.name, e.classes.map { |c| c.name }].flatten }
    assert_array_equal env_class_map, [["master", "test"], ["prod", "test1", "test2"], ["dev", "test3", "test4"]]
  end

  def test_multiple_modulepath_in_single_env_with_dynamic_path
    config = {
        :main => {},
        :master => { :modulepath=>'./test/fixtures/environments/$environment:./test/fixtures/modules_include' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['dev', 'prod', 'master']
  end

  def test_multiple_modulepath_in_single_env_with_broken_entry
    config = {
        :main => {},
        :master => { :modulepath=>'./no/such/$environment/modules:./test/fixtures/environments/prod' }
    }
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns(config)
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['master']
  end

  def test_use_environment_api_with_environmentpath_set_main
    assert Proxy::Puppet::Environment.send(:use_environment_api?, :main => {:environmentpath => '/etc'})
  end

  def test_use_environment_api_with_environmentpath_set_master
    assert Proxy::Puppet::Environment.send(:use_environment_api?, :master => {:environmentpath => '/etc'})
  end

  def test_use_environment_api_with_no_environmentpath
    assert !Proxy::Puppet::Environment.send(:use_environment_api?, {})
  end

  def test_use_environment_api_override_false
    Proxy::Puppet::Plugin.settings.stubs(:puppet_use_environment_api).returns(false)
    assert !Proxy::Puppet::Environment.send(:use_environment_api?, :main => {:environmentpath => '/etc'})
  end

  def test_use_environment_api_override_true
    Proxy::Puppet::Plugin.settings.stubs(:puppet_use_environment_api).returns(true)
    assert Proxy::Puppet::Environment.send(:use_environment_api?, {})
  end

  def test_all_calls_config_environments
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns({})
    Proxy::Puppet::Environment.expects(:use_environment_api?).returns(false)
    Proxy::Puppet::Environment.expects(:config_environments).returns({})
    Proxy::Puppet::Environment.all
  end

  def test_all_calls_api_environments
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns({})
    Proxy::Puppet::Environment.expects(:use_environment_api?).returns(true)
    Proxy::Puppet::Environment.expects(:api_environments).returns({})
    Proxy::Puppet::Environment.all
  end

  def test_api_environments
    api = mock('EnvironmentsApi')
    api.expects(:find_environments).returns(JSON.load(File.read('./test/fixtures/environments_api.json')))
    Proxy::Puppet::EnvironmentsApi.expects(:new).returns(api)

    envs = Proxy::Puppet::Environment.send(:api_environments)
    assert_equal ['production', 'example_env', 'development', 'common'].sort, envs.keys.sort
    ['production', 'example_env', 'development', 'common'].each do |e|
      assert_equal ["/etc/puppet/environments/#{e}/modules", "/etc/puppet/modules", "/usr/share/puppet/modules"], envs[e]
    end
  end

  def test_should_provide_puppet_envs_from_api
    Proxy::Puppet::ConfigReader.any_instance.stubs(:get).returns({})
    Proxy::Puppet::Environment.expects(:use_environment_api?).returns(true)
    Proxy::Puppet::Environment.expects(:api_environments).returns('production' => ['/etc/puppet/environments/production/modules', '/etc/puppet/modules'])
    env = Proxy::Puppet::Environment.all
    assert_array_equal env.map { |e| e.name }, ['production']
  end

  private

  def mock_puppet_env
    Proxy::Puppet::Environment.stubs(:config_environments).with(is_a(Hash)).returns(:production => "./test/fixtures/environments/prod")
    Proxy::Puppet::Environment.all
  end

  def assert_array_equal(expected, actual, message=nil)
      full_message = build_message(message, "<?> expected but was\n<?>.\n", expected, actual)
      assert_block(full_message) { (expected.size ==  actual.size) && (expected - actual == []) }
  end

end
