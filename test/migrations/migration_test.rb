require 'test_helper'
require File.join(File.dirname(__FILE__),'../../extra/migrate_settings')

class MigrationTest < Test::Unit::TestCase
  def setup
    @module = Module.new

    @migration = ::Proxy::Migrations.new("dummy", ["#{@module}::TestMigrationOne", "#{@module}::TestMigrationTwo"])
    ::Proxy::Migration.inject_migrations_instance(@migration)

    @module.module_eval(File.read('./test/migrations/1_test_migration_one.rb'))
    @module.module_eval(File.read('./test/migrations/2_test_migration_two.rb'))
    @module.module_eval(File.read('./test/migrations/3_test_migration_three.rb'))
  end

  def test_migration_classes_are_ordered
    assert_equal ["#{@module}::TestMigrationOne", "#{@module}::TestMigrationTwo", "#{@module}::TestMigrationThree"],
                 @migration.migrations.map(&:name)
  end

  def test_migration_list_filtering
    assert_equal ["#{@module}::TestMigrationThree"], @migration.new_migrations.map(&:name)
  end

  def test_migrations_setup_with_monolithic_config
    migrator = ::Proxy::Migrator.new(
        "./dummy", "./dummy", "./config/settings.yml", "./dummy", ::Proxy::Migrations.new("./dummy", []))
    FileUtils.expects(:cp).with("./config/settings.yml", "./migrations_dir").returns(true)
    File.expects(:exist?).with("./dummy").returns(false)
    migrator.copy_original_configuration("./migrations_dir")
  end

  def test_migrations_setup_with_modularized_config
    migrator = ::Proxy::Migrator.new(
        "./dummy", "./dummy", "./config/settings.yml", "./settings.d", ::Proxy::Migrations.new("./dummy", []))
    FileUtils.expects(:cp).with("./config/settings.yml", "./migrations_dir").returns(true)
    File.expects(:exist?).with("./settings.d").returns(true)
    FileUtils.expects(:cp_r).with("./settings.d/.", "./migrations_dir/settings.d")
    migrator.copy_original_configuration("./migrations_dir")
  end

  def test_migrations_fail_without_migrations_dir
    migrator = ::Proxy::Migrator.new(
        "./work_dir", "./migrations_dir", "./config/dummy-settings.yml", "./modules_config_dir",
        ::Proxy::Migrations.new("./dummy", []))

    assert_raise RuntimeError do
      migrator.verify_paths
    end
  end

  def test_migrations_fail_without_original_configuration
    migrator = ::Proxy::Migrator.new(
        "./work_dir", "./migrations_dir", "./config/dummy-settings.yml", "./modules_config_dir",
        ::Proxy::Migrations.new("./dummy", []))
    File.expects(:directory?).with("./migrations_dir").returns(true)
    assert_raise RuntimeError do
      migrator.verify_paths
    end
  end

  def test_copy_original_configuration
    migrator = ::Proxy::Migrator.new(
        "./work_dir", "./migrations_dir", "./config/dummy-settings.yml", "./modules_config_dir",
        ::Proxy::Migrations.new("./dummy", []))

    FileUtils.expects(:cp).with("./config/dummy-settings.yml", "./destination_path")
    File.expects(:exist?).with("./modules_config_dir").returns(true)
    FileUtils.expects(:cp_r).with("./modules_config_dir/.", "./destination_path/settings.d")

    migrator.copy_original_configuration("./destination_path")
  end

  def test_copy_previous_migration_results
    migrator = ::Proxy::Migrator.new(
        "./work_dir", "./migrations_dir", "./config/dummy-settings.yml", "./modules_config_dir",
        ::Proxy::Migrations.new("./dummy", []))

    FileUtils.expects(:cp_r).with("./previous_migration_results/.", "./next_migration_src")

    migrator.copy_previous_migration_results("./previous_migration_results", "./next_migration_src")
  end

  def test_create_migration_dirs
    Dir.mktmpdir do |tmp|
      migration = ::Proxy::Migration.new(tmp)
      migration.create_migration_dirs

      assert File.exist?(migration.src_dir)
      assert File.exist?(migration.dst_dir)
      assert File.exist?(File.join(migration.dst_dir, "settings.d"))
    end
  end

  def test_execute_a_migration
    migrator = ::Proxy::Migrator.new(
        "./work_dir", "./migrations_dir", "./config/dummy-settings.yml", "./modules_config_dir",
        ::Proxy::Migrations.new("./dummy", []))

    migration = @migration.migrations.first.new("./work_dir")
    @migration.migrations.first.any_instance.expects(:create_migration_dirs)
    migrator.expects(:copy_original_configuration).with(migration.src_dir)

    migrator.execute_migrations([@migration.migrations.first])

    assert_equal 1, migrator.executed_migrations.size
    assert migrator.executed_migrations.first.instance_of?(@migration.migrations.first)
  end

  def test_copy_original_configuration_skips_files_in_config_dir
    Dir.mktmpdir do |tmp|
      migration = ::Proxy::Migration.new(tmp)
      setup_test_migration_dirs(migration)

      migration.copy_original_configuration_except("settings.yml")

      assert !File.exist?(File.join(migration.dst_dir, "settings.yml"))
    end
  end

  def test_copy_original_configuration_skips_files_in_modulesconfig_dir
    Dir.mktmpdir do |tmp|
      migration = ::Proxy::Migration.new(tmp)
      setup_test_migration_dirs(migration)

      migration.copy_original_configuration_except(File.join("settings.d", "test_module.yml"))

      assert !File.exist?(File.join(migration.dst_dir, "settings.d", "test_module.yml"))
    end
  end

  def setup_test_migration_dirs(migration)
    migration.create_migration_dirs
    FileUtils.touch(File.join(migration.src_dir, "settings.yml"))
    FileUtils.mkdir_p(File.join(migration.src_dir, "settings.d"))
    FileUtils.touch(File.join(migration.src_dir, "settings.d", "test_module.yml"))
  end
end
