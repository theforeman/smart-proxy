require 'test_helper'

require File.join(__dir__, '../../extra/migrate_settings')
Proxy::Migration.inject_migrations_instance(Proxy::Migrations.new("dummy"))
require File.join(__dir__, '../../extra/migrations/20170523000000_migrate_autosign_setting.rb')

class ProxyAutosignMigrationTest < Test::Unit::TestCase
  def setup
    @migration = MigrateAutosignSetting.new("/tmp")
  end

  def test_autosign_parameter_remapping
    assert_equal [:puppetca, :autosignfile, '/etc/puppet/autosign.conf'], @migration.remap_parameter(:puppetdir, '/etc/puppet')
  end
end
