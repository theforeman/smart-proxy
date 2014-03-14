require 'test_helper'

class PuppetEnvironmentTest < Test::Unit::TestCase

  def test_puppet_class_should_be_an_opject
    klass = Proxy::Puppet::Environment.new :name => "production", :paths => ["/etc/puppet/env/production"]
    assert_kind_of Proxy::Puppet::Environment, klass
  end

  def test_should_provide_puppet_envs
    env = Proxy::Puppet::Environment.send(:puppet_environments)
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

  private

  def mock_puppet_env
    Proxy::Puppet::Environment.stubs(:puppet_environments).returns({:production => "./test/fixtures/environments/prod"})
    Proxy::Puppet::Environment.all
  end

  def assert_array_equal(expected, actual, message=nil)
      full_message = build_message(message, "<?> expected but was\n<?>.\n", expected, actual)
      assert_block(full_message) { (expected.size ==  actual.size) && (expected - actual == []) }
  end

end
