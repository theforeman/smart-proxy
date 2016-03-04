require 'test_helper'
require File.join(File.dirname(__FILE__),'../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(File.dirname(__FILE__),'../../extra/migrations/20160411000000_migrate_libvirt_settings')

class ProxyLibvirtMigrationTest < Test::Unit::TestCase

  def setup
    @old_config = YAML.load_file(File.join(File.dirname(__FILE__),'./migration_settings.yml'))
    @migration = MigrateVirshToLibvirtConfig.new("/tmp")
    @dhcp_data = @migration.transform_dhcp_yaml(@old_config.dup)
    @dns_data = @migration.transform_dns_yaml(@old_config.dup)
  end

  def test_transform_dhcp_yaml_empty
    assert_equal 'default', @migration.transform_dhcp_yaml({})[:network]
  end

  def test_output_has_correct_dhcp_network
    assert_equal 'mynetwork', @dhcp_data[:network]
  end

  def test_transform_dns_yaml_empty
    assert_equal 'default', @migration.transform_dns_yaml({})[:network]
  end

  def test_output_has_correct_dns_network
    assert_equal 'mynetwork', @dns_data[:network]
  end
end
