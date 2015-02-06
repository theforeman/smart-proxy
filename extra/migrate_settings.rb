require 'pathname'
require 'fileutils'
require 'optparse'
require 'yaml'

module ::Proxy
  class Migrations
    attr_reader :migrations, :past_migrations, :migration_state_file_path

    def initialize(migration_state_file_path, past_migrations = [])
      @past_migrations = past_migrations
      @migration_state_file_path = migration_state_file_path
    end

    def load_past_migrations!
      raise "Migration state file #{@migration_state_file_path} can't be found" unless File.exist?(@migration_state_file_path)
      @past_migrations = File.read(@migration_state_file_path).split("\n")
      self
    end

    def register_migration(migration_class)
      @migrations ||= []
      @migrations << migration_class
    end

    def new_migrations
      # don't want to deal with namespaced constant resolution/loading
      migrations.select {|m| !past_migrations.include?(m.name) }
    end

    def persist_migrations_state(migrations, result_dir_path)
      migration_state = File.open(File.join(result_dir_path, "migration_state"), "w")
      migration_state.write((past_migrations + migrations).uniq.join("\n"))
    ensure
      migration_state.close unless migration_state.nil?
    end
  end

  class Migration
    attr_reader :working_dir_path

    class << self
      def inject_migrations_instance(migrations)
        @@migrations = migrations
      end

      def inherited(subclass)
        @@migrations.register_migration(subclass)
      end
    end

    def initialize(working_dir_path)
      @working_dir_path = working_dir_path
    end

    def migration_name
      underscore(self.class.name)
    end

    def migration_dir
      File.join(working_dir_path, migration_name)
    end

    def src_dir
      File.join(migration_dir, "src")
    end

    def dst_dir
      File.join(migration_dir, "dst")
    end

    def path(*segments)
      File.join(segments)
    end

    def duplicate_original_configuration
      FileUtils.cp_r(path(src_dir, '.'), dst_dir)
    end

    def copy_original_configuration_except(*exceptions)
      FileUtils.cp_r(Dir.glob(path(src_dir, "*.yml")) - exceptions.map { |e| path(src_dir, e) }, dst_dir)
      FileUtils.cp_r(
          Dir.glob(path(src_dir, "settings.d", "*.*")) - exceptions.map { |e| path(src_dir, e) },
          path(dst_dir, "settings.d"))
    end

    def create_migration_dirs
      FileUtils.mkdir_p(src_dir)
      FileUtils.mkdir_p(File.join(dst_dir, "settings.d"))
    end

    def underscore(src)
      src = src.gsub(/::/, '/')
      src = src.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      src = src.gsub(/([a-z\d])([A-Z])/,'\1_\2')
      src = src.tr("-", "_")
      src.downcase
    end
  end

  class Migrator
    attr_reader :working_dir_path, :migrations_dir_path, :config_src_path, :modules_config_src_path, :result_dir_path
    attr_reader :executed_migrations

    def initialize(working_dir_path, migrations_dir_path, config_src_path, modules_config_src_path, migrations)
      @working_dir_path = working_dir_path
      @migrations_dir_path = migrations_dir_path
      @config_src_path = config_src_path
      @modules_config_src_path = modules_config_src_path
      @migrations = migrations
      @result_dir_path = File.join(working_dir_path, 'result')
      @executed_migrations = []
    end

    def load_migrations(migrations_dir_path)
      migration_files = Dir.glob(File.join(migrations_dir_path, "*.rb")).sort
      ::Proxy::Migration.inject_migrations_instance(@migrations)
      migration_files.each { |file| require file }
    end

    def migrate
      FileUtils.mkdir_p(result_dir_path)

      verify_paths
      print_used_values
      load_migrations(migrations_dir_path)

      puts "Running migrations..."
      execute_migrations(@migrations.new_migrations)
    ensure
      copy_migration_results_to_results_dir(result_dir_path)
      persist_migrations_state(executed_migrations, result_dir_path)
    end

    def execute_migrations(migrations)
      migrations.each do |migration|
        m = migration.new(working_dir_path)
        puts "#{m.migration_name}"

        m.create_migration_dirs
        if migration == migrations.first
          copy_original_configuration(m.src_dir)
        else
          copy_previous_migration_results(executed_migrations.last.dst_dir, m.src_dir)
        end

        m.migrate
        executed_migrations << m
      end
    end

    def verify_paths
      raise "Migrations dir '#{migrations_dir_path}' doesn't exist" unless File.directory?(migrations_dir_path)
      raise "Settings file '#{config_src_path}' doesn't exist" unless File.exist?(config_src_path)
    end

    def print_used_values
      used_values = %{using:
  config file: #{config_src_path},
  modules config dir: #{modules_config_src_path},
  working dir: #{working_dir_path},
  migrations dir: #{migrations_dir_path},
  migrations state path: #{@migrations.migration_state_file_path}
      }
      puts used_values
    end

    def copy_migration_results_to_results_dir(results_dir)
      if executed_migrations.empty?
        copy_original_configuration(results_dir)
      else
        copy_to_results_dir(executed_migrations.last.dst_dir, results_dir)
      end
    end

    def persist_migrations_state(migrations, path)
      @migrations.persist_migrations_state(migrations.map {|m| m.class.name}, path)
    rescue Exception => e
      p "Couldn't save migration state: #{e}"
    end

    def copy_original_configuration(dst_dir)
      FileUtils.cp(config_src_path, dst_dir)
      if File.exist?(modules_config_src_path)
        FileUtils.cp_r(File.join(modules_config_src_path, '.'), File.join(dst_dir, "settings.d"))
      end
    end

    def copy_previous_migration_results(result_dir, src_dir)
      FileUtils.cp_r(File.join(result_dir, '.'), src_dir)
    end

    def copy_to_results_dir(dst_dir, result_dir)
      FileUtils.cp_r(File.join(dst_dir, '.'), result_dir)
    end
  end
end

def app_dir
  path("../../", __FILE__)
end

def path(part_one, part_two = nil)
  File.expand_path(part_one, part_two)
end

def parse_cli_options(args)
  result = {}

  result[:cfg_path] = path("settings.yml", path("config", app_dir))
  result[:modules_cfg_path] = module_configuration_dir(load_main_config_file(result[:cfg_path]))
  result[:tmp_dir] = path("tmp", app_dir)
  result[:migrations_dir] = path("migrations", path("extra", app_dir))
  result[:migrations_state] = path("migration_state", path("config", app_dir))

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: migrate.rb [options]"
    opts.separator ""

    opts.on('-c', '--config_file CFG_FILE_PATH', 'main configuration file path (read-only)') do |cfg_path|
      result[:cfg_path] = path(cfg_path)
    end
    opts.on('-d', '--modules_config_dir MODULES_CFG_PATH', 'modules configuration directory path (read-only)') do |m_cfg_path|
      result[:modules_cfg_path] = path(m_cfg_path)
    end
    opts.on('-t', '--tmp_dir TMP_DIR_PATH', 'working directory path') do |tmp_dir|
      result[:tmp_dir] = path(tmp_dir)
    end
    opts.on('-m', '--migrations_dir MIGRATIONS_DIR_PATH', 'migrations directory path (read-only)') do |migrations_dir|
      result[:migrations_dir] = path(migrations_dir)
    end
    opts.on('-s', '--migration_state MIGRATION_STATE_PATH', 'path to the file storing executed migrations (read-only)') do |ms_path|
      result[:migrations_state] = path(ms_path)
    end
  end

  parser.parse!(args)
  result
end

def load_main_config_file(main_config_file_path)
  YAML.load(File.read(main_config_file_path)) || {}
end

def module_configuration_dir(main_config_file)
  main_config_file[:settings_directory] || Pathname.new(__FILE__).join("..", "..", "config", "settings.d").expand_path.to_s
end

if __FILE__ == $0 then
  options = parse_cli_options(ARGV)

  config_src_path = options[:cfg_path]
  modules_config_src_path = options[:modules_cfg_path]
  working_dir_path = options[:tmp_dir]
  migrations_dir_path = options[:migrations_dir]
  migrations_state_file_path = options[:migrations_state]

  ::Proxy::Migrator.new(
      working_dir_path, migrations_dir_path, config_src_path, modules_config_src_path,
      ::Proxy::Migrations.new(migrations_state_file_path).load_past_migrations!).migrate
  exit(0)
end
