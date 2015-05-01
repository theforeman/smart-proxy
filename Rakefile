require 'rake'
require 'rake/testtask'
require 'rdoc/task'
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
  t.test_files  = FileList['test/**/*_test.rb']
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
