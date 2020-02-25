require 'test_helper'

require File.join(File.dirname(__FILE__), '../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(File.dirname(__FILE__), '../../extra/migrations/20160413000000_migrate_puppet_settings.rb')

class ProxyPuppetMigrationTest < Test::Unit::TestCase
  def setup
    @migration = MigratePuppetSettings.new("/tmp")
  end

  def test_old_to_new_provider_name_conversion
    assert_equal 'puppet_proxy_puppetrun', @migration.old_provider_name_to_new('puppetrun')
    assert_equal 'puppet_proxy_mcollective', @migration.old_provider_name_to_new('mcollective')
    assert_equal 'puppet_proxy_salt', @migration.old_provider_name_to_new('salt')
    assert_equal 'puppet_proxy_customrun', @migration.old_provider_name_to_new('customrun')
    assert_equal 'puppet_proxy_ssh', @migration.old_provider_name_to_new('puppetssh')
    assert_equal 'unknown', @migration.old_provider_name_to_new('unknown')
  end

  def test_puppet_parameter_remapping
    assert_equal [:puppet, :enabled, true], @migration.remap_parameter(:enabled, true).flatten
    assert_equal [:puppet, :use_provider, 'puppet_proxy_salt'], @migration.remap_parameter(:puppet_provider, 'salt').flatten
  end

  def test_puppet_api_parameter_mapping
    assert_equal [:puppet_proxy_puppet_api, :puppet_url, 'http://localhost'], @migration.remap_parameter(:puppet_url, "http://localhost").last
    assert_equal [:puppet_proxy_puppet_api, :puppet_ssl_ca, 'some/path'], @migration.remap_parameter(:puppet_ssl_ca, "some/path").last
    assert_equal [:puppet_proxy_puppet_api, :puppet_ssl_cert, 'some/path'], @migration.remap_parameter(:puppet_ssl_cert, "some/path").last
    assert_equal [:puppet_proxy_puppet_api, :puppet_ssl_key, 'some/path'], @migration.remap_parameter(:puppet_ssl_key, "some/path").last
  end

  def test_puppet_ssh_parameter_mapping
    assert_equal [:puppet_proxy_ssh, :use_sudo, true], @migration.remap_parameter(:puppetssh_sudo, true).flatten
    assert_equal [:puppet_proxy_ssh, :command, "command"], @migration.remap_parameter(:puppetssh_command, "command").flatten
    assert_equal [:puppet_proxy_ssh, :wait, true], @migration.remap_parameter(:puppetssh_wait, true).flatten
    assert_equal [:puppet_proxy_ssh, :user, "user"], @migration.remap_parameter(:puppetssh_user, "user").flatten
    assert_equal [:puppet_proxy_ssh, :keyfile, "keyfile"], @migration.remap_parameter(:puppetssh_keyfile, "keyfile").flatten
  end

  def test_puppet_mcollective_parameter_mapping
    assert_equal [:puppet_proxy_mcollective, :puppet_user, "user"], @migration.remap_parameter(:puppet_user, "user").last
    assert_equal [:puppet_proxy_mcollective, :user, "user"], @migration.remap_parameter(:mcollective_user, "user").first
  end

  def test_puppetrun_parameter_mapping
    assert_equal [:puppet_proxy_puppetrun, :puppet_user, "user"], @migration.remap_parameter(:puppet_user, "user").first
  end

  def test_puppet_salt_parameter_mapping
    assert_equal [:puppet_proxy_salt, :command, "command"], @migration.remap_parameter(:salt_puppetrun_cmd, "command").first
  end

  def test_puppet_customrun_parameter_mapping
    assert_equal [:puppet_proxy_customrun, :command, "command"], @migration.remap_parameter(:customrun_cmd, "command").first
    assert_equal [:puppet_proxy_customrun, :command_arguments, "arg1 arg2"], @migration.remap_parameter(:customrun_args, "arg1 arg2").first
  end

  def test_remapping_of_unknown_parameter
    assert_equal [:unknown, :a_parameter, 'avalue'], @migration.remap_parameter(:a_parameter, 'avalue').first
  end

  def test_migrate_puppet_user_for_puppetrun
    assert_equal "a_user", @migration.migrate_puppet_configuration(:puppet_user => "a_user")[:puppet_proxy_puppetrun][:user]
    assert_nil @migration.migrate_puppet_configuration(:puppet_user => "a_user")[:puppet_proxy_puppetrun][:puppet_user]
  end

  def test_migrate_puppet_user_for_mcollective
    assert_equal "a_user", @migration.migrate_puppet_configuration(:puppet_user => "a_user")[:puppet_proxy_mcollective][:user]
    assert_nil @migration.migrate_puppet_configuration(:puppet_user => "a_user")[:puppet_proxy_mcollective][:puppet_user]
  end

  def test_migrate_puppet_configuration
    assert_equal({:puppet => {:enabled => true}, :puppet_proxy_puppet_api => {:puppet_url => "http://localhost"}},
                 @migration.migrate_puppet_configuration(:enabled => true, :puppet_url => "http://localhost"))
  end
end
