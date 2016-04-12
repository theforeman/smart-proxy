require 'test_helper'

require File.join(File.dirname(__FILE__),'../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(File.dirname(__FILE__),'../../extra/migrations/20160301000000_set_puppet_version_in_puppet_proxy_settings.rb')

class PuppetVersionInPuppetProxyMigrationTest < Test::Unit::TestCase
  def setup
    @migration = SetPuppetVersionInPuppetProxySettings.new("/tmp")
  end

  def test_migration_adds_puppet_version
    @migration.stubs(:puppet_version).returns("4.3.1")
    migrated = @migration.migrate_puppet_configuration({})
    assert_equal "4.3.1", migrated[:puppet_version]
  end
end
