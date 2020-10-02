require 'test_helper'

require File.join(__dir__, '../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(__dir__, '../../extra/migrations/20161209000000_migrate_realm_settings.rb')

class ProxyRealmMigrationTest < Test::Unit::TestCase
  def setup
    @migration = MigrateRealmSettings.new("/tmp")
  end

  def test_freeipa_parameter_remapping
    assert_equal [:realm_freeipa, :keytab_path, 'some/path'], @migration.remap_parameter(:realm_keytab, 'some/path')
    assert_equal [:realm_freeipa, :principal, 'a_principal'], @migration.remap_parameter(:realm_principal, 'a_principal')
    assert_equal [:realm_freeipa, :remove_dns, true], @migration.remap_parameter(:freeipa_remove_dns, true)
  end

  def test_realm_parameter_remapping
    assert_equal [:realm, :enabled, true], @migration.remap_parameter(:enabled, true)
  end

  def test_migration_adds_use_provider_setting
    assert_equal({:realm => {:use_provider => 'realm_freeipa'}}, @migration.migrate_realm_configuration({}))
  end
end
