require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'tmpdir'
require File.join(__dir__, 'extra/migrate_settings')

load 'tasks/jenkins.rake'
load 'tasks/pkg.rake'
load 'tasks/rubocop.rake'

desc 'Default: run unit tests.'
task :default => :test


# Collect all test files, excluding those specified in the SKIP_TEST_FILES environment variable
all_test_files = FileList['test/**/*_test.rb']
skip_tests = ENV['SKIP_TEST_FILES'] ? ENV['SKIP_TEST_FILES'].split(',') : []

# remove all tests which start with test/#{skip_test}
test_files = all_test_files.reject do |file|
  skip_tests.any? { |skip_test| file.start_with?("test/#{skip_test}") }
end

desc 'Test the Foreman Proxy plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << '.'
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = test_files
  t.verbose = true
  t.ruby_opts = ["-W1"]
end

begin
  require 'rdoc/task'
rescue LoadError
  # No rdoc
else
  desc 'Generate documentation for the Foreman Proxy plugin.'
  Rake::RDocTask.new(:rdoc) do |rdoc|
    rdoc.rdoc_dir = 'rdoc'
    rdoc.title    = 'Proxy'
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('README.md')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
end

desc 'Migrate configuration settings.'
task :migrate_settings do
  app_dir = __dir__
  config_src_path = File.join(app_dir, "config", "settings.yml")
  modules_config_src_path = File.join(app_dir, "config", "settings.d")
  migrations_dir_path = File.join(app_dir, "extra", "migrations")
  migrations_state_file_path = File.join(app_dir, "config", "migration_state")
  FileUtils.touch(migrations_state_file_path)

  Dir.mktmpdir do |working_dir|
    ::Proxy::Migrator.new(
      working_dir, migrations_dir_path, config_src_path, modules_config_src_path,
      ::Proxy::Migrations.new(migrations_state_file_path).load_past_migrations!).migrate

    FileUtils.mv(File.join(app_dir, "config"), File.join(app_dir, "config_#{Time.now.strftime('%Y%m%d%H%M%S')}"))
    FileUtils.mv(File.join(working_dir, "result"), File.join(app_dir, "config"))
  end
end
