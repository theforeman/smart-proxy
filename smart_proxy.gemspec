require 'rake'

spec = Gem::Specification.new do |s|
  s.name = "smart_proxy"
  s.version = File.read(File.join(File.dirname(__FILE__), 'VERSION')).chomp.gsub('-', '.')
  s.author = "Ohad Levy"
  s.email = "ohadlevy@gmail.com"
  s.homepage = "http://theforeman.org/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Foreman Proxy Agent, manage remote DHCP, DNS, TFTP and Puppet servers"
  s.files = FileList["{bin,public,config,views,lib,modules}/**/*", "VERSION"].to_a
  s.default_executable = 'bin/smart_proxy.rb'
  s.require_paths = ["lib", "modules"]
  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.license = 'GPLv3'
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency 'json', '~> 1.8'
  s.add_dependency 'rack', '~> 1.5'
  s.add_dependency 'sinatra', '~> 1.4'
  s.rubyforge_project = 'rake'
  s.description = <<EOF
Foreman Proxy is used via The Foreman Project, it allows Foreman to manage
Remote DHCP, DNS, TFTP and Puppet servers via a REST API
EOF
end

