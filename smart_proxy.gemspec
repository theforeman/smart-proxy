Gem::Specification.new do |s|
  s.name = "smart_proxy"
  s.version = File.read(File.join(File.dirname(__FILE__), 'VERSION')).chomp.gsub('-', '.')
  s.author = "Ohad Levy"
  s.email = "ohadlevy@gmail.com"
  s.homepage = "http://theforeman.org/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Foreman Proxy Agent, manage remote DHCP, DNS, TFTP and Puppet servers"
  s.files = (Dir.glob("{bin,public,config,views,lib,modules}/**/*") + ["VERSION"])
  s.executables << 'smart-proxy'
  s.require_paths = ["lib", "modules"]
  s.test_files = Dir.glob("{test}/**/*test.rb")
  s.license = 'GPLv3'
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.md"]
  s.add_dependency 'json' 
  s.add_dependency 'rack', '>= 1.1', '< 1.6' # ruby 1.8.7 support is broken in rack 1.6 versions < 1.6.4
  s.add_dependency 'sinatra'
  s.description = <<EOF
Foreman Proxy is used via The Foreman Project, it allows Foreman to manage
Remote DHCP, DNS, TFTP and Puppet servers via a REST API
EOF
end
