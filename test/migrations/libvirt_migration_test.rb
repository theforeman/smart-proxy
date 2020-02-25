require 'test_helper'
require File.join(File.dirname(__FILE__), '../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(File.dirname(__FILE__), '../../extra/migrations/20160411000000_migrate_libvirt_settings')

class ProxyLibvirtMigrationTest < Test::Unit::TestCase
  def setup
    @old_config = YAML.load_file(File.join(File.dirname(__FILE__), './migration_settings.yml'))
    @migration = MigrateVirshToLibvirtConfig.new("/tmp")
  end

  def test_transform_main_dhcp_configuration
    assert_equal({:use_provider => 'dhcp_libvirt'}, @migration.transform_dhcp_yaml(:use_provider => 'dhcp_virsh'))
  end

  def test_transform_main_dhcp_configuration_when_another_provider_is_used
    assert_equal({:use_provider => 'dhcp_isc'}, @migration.transform_dhcp_yaml(:use_provider => 'dhcp_isc'))
  end

  def test_transform_dhcp_yaml_empty
    assert_equal 'default', @migration.transform_dhcp_libvirt_yaml({})[:network]
  end

  def test_output_has_correct_dhcp_network
    assert_equal 'mynetwork', @migration.transform_dhcp_libvirt_yaml(@old_config.dup)[:network]
  end

  def test_transform_dns_yaml_empty
    assert_equal 'default', @migration.transform_dns_libvirt_yaml({})[:network]
  end

  def test_transform_main_dns_configuration
    assert_equal({:use_provider => 'dns_libvirt'}, @migration.transform_dns_yaml(:use_provider => 'dns_virsh'))
  end

  def test_transform_main_dns_configuration_when_another_provider_is_used
    assert_equal({:use_provider => 'dns_nsupdate'}, @migration.transform_dns_yaml(:use_provider => 'dns_nsupdate'))
  end

  def test_output_has_correct_dns_network
    assert_equal 'mynetwork', @migration.transform_dns_libvirt_yaml(@old_config.dup)[:network]
  end
end
