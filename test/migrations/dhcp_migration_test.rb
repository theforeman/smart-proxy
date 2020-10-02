require 'test_helper'

require File.join(__dir__, '../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(__dir__, '../../extra/migrations/20150826000000_migrate_dhcp_settings')

class ProxyDhcpMigrationTest < Test::Unit::TestCase
  def setup
    @migration = MigrateDhcpSettings.new("/tmp")
  end

  def test_old_to_new_provider_name_conversion
    assert_equal 'dhcp_isc', @migration.old_provider_name_to_new('isc')
    assert_equal 'dhcp_native_ms', @migration.old_provider_name_to_new('native_ms')
    assert_equal 'dhcp_virsh', @migration.old_provider_name_to_new('virsh')
    assert_equal 'unknown', @migration.old_provider_name_to_new('unknown')
  end

  def test_dhcp_parameter_remapping
    assert_equal [:dhcp, :enabled, true], @migration.remap_parameter(:enabled, true)
    assert_equal [:dhcp, :use_provider, 'dhcp_isc'], @migration.remap_parameter(:dhcp_vendor, 'isc')
    assert_equal [:dhcp, :subnets, ['192.168.205.0/255.255.255.128']],
                 @migration.remap_parameter(:dhcp_subnets, ['192.168.205.0/255.255.255.128'])
    assert_equal [:dhcp, :server, 'test.nowhere'], @migration.remap_parameter(:dhcp_server, 'test.nowhere')
  end

  def test_dhcp_isc_parameter_mapping
    assert_equal [:dhcp_isc, :config, 'some/path'], @migration.remap_parameter(:dhcp_config, 'some/path')
    assert_equal [:dhcp_isc, :leases, 'some/path'], @migration.remap_parameter(:dhcp_leases, 'some/path')
    assert_equal [:dhcp_isc, :key_name, 'key_name'], @migration.remap_parameter(:dhcp_key_name, 'key_name')
    assert_equal [:dhcp_isc, :key_secret, 'key_secret'], @migration.remap_parameter(:dhcp_key_secret, 'key_secret')
    assert_equal [:dhcp_isc, :omapi_port, '12345'], @migration.remap_parameter(:dhcp_omapi_port, '12345')
  end

  def test_test_dhcp_parameter_remapping_of_unknown_parameter
    assert_equal [:unknown, :a_parameter, 'avalue'], @migration.remap_parameter(:a_parameter, 'avalue')
  end

  def test_migrate_dhcp_configuration
    results =
      @migration.migrate_dhcp_configuration(:enabled => true,
                                            :dhcp_config => 'config/path', :dhcp_server => 'localhost')

    assert_equal true, results[:dhcp][:enabled]
    assert_equal 'config/path', results[:dhcp_isc][:config]
    assert_equal 'localhost', results[:dhcp][:server]
    assert_equal 2, results.size
  end

  def test_write_results_to_files
    Dir.mktmpdir do |tmp_dir|
      migration = MigrateDhcpSettings.new(tmp_dir)
      migration.create_migration_dirs

      migration.write_to_files(
        :dhcp => {:enabled => true},
        :dhcp_isc => {:config => 'some/path'},
        :unknown => {:parameter => 'value'})

      assert File.exist?(dhcp_config_path = File.join(migration.dst_dir, 'settings.d', 'dhcp.yml'))
      dhcp_contents = File.read(dhcp_config_path)

      assert dhcp_contents.include?(':enabled: true')
      assert dhcp_contents.include?(':parameter: value')

      assert File.exist?(isc_config_path = File.join(migration.dst_dir, 'settings.d', 'dhcp_isc.yml'))
      isc_contents = File.read(isc_config_path)
      assert isc_contents.include?(':config: some/path')
    end
  end
end
