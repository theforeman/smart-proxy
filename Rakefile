require 'rake'
require 'rake/testtask'
require 'rdoc/task'
require 'fileutils'
require 'tmpdir'
require File.join(File.dirname(__FILE__),'extra/migrate_settings')

load 'tasks/proxy_tasks.rake'
load 'tasks/jenkins.rake'
load 'tasks/pkg.rake'
load 'tasks/rubocop.rake' if RUBY_VERSION > "1.9.2"

# Test for 1.9
if (RUBY_VERSION.split('.').map{|s|s.to_i} <=> [1,9,0]) > 0 then
  PLATFORM = RUBY_PLATFORM
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the Foreman Proxy plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << '.'
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

desc 'Generate documentation for the Foreman Proxy plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Proxy'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Migrate configuration settings.'
task :migrate_settings do
  app_dir = File.dirname(__FILE__)
  config_src_path = File.join(app_dir, "config", "settings.yml")
  modules_config_src_path = File.join(app_dir, "config", "settings.d")
  migrations_dir_path = File.join(app_dir, "extra", "migrations")
  migrations_state_file_path = File.join(app_dir, "config", "migration_state")
  FileUtils.touch(migrations_state_file_path)

  Dir.mktmpdir do |working_dir|
    ::Proxy::Migrator.new(
        working_dir, migrations_dir_path, config_src_path, modules_config_src_path,
        ::Proxy::Migrations.new(migrations_state_file_path).load_past_migrations!).migrate

    FileUtils.mv(File.join(app_dir, "config"), File.join(app_dir, "config_#{Time.now.strftime("%Y%m%d%H%M%S")}"))
    FileUtils.mv(File.join(working_dir, "result"), File.join(app_dir, "config"))
  end
end
