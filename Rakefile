require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the Foreman Proxy plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  files = FileList['test/**/*_test.rb']
  if PLATFORM =~ /mingw/
    files = FileList['test/**/server_ms_test*']
  else
    files = FileList['test/**/*_test.rb'].delete_if{|f| f =~ /_ms_/}
  end
  t.test_files  = files
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

spec = Gem::Specification.new do |s|
  s.name = "foreman_proxy"
  s.version = "0.0.2"
  s.author = "Ohad Levy"
  s.email = "ohadlevy@gmail.com"
  s.homepage = "http://theforeman.org/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Foreman Proxy Agent, manage remote DHCP, DNS, TFTP and Puppet servers"
  s.files = FileList["{bin,public,config,views,lib}/**/*"].to_a
  s.default_executable = 'bin/smart_proxy.rb'
  s.require_path = "lib"
  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency 'json'
  s.add_dependency 'sinatra'
  s.add_dependency 'net/ping'
  s.rubyforge_project = 'rake'
  s.description = <<EOF
Foreman Proxy is used via The Foreman Project, it allows Foreman to manage
Remote DHCP, DNS, TFTP and Puppet servers via a REST API
EOF
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar_gz = true
end
