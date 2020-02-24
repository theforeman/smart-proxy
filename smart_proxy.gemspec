Gem::Specification.new do |s|
  s.name = "smart_proxy"
  s.version = File.read(File.join(__dir__, 'VERSION')).chomp.tr('-', '.')
  s.author = "Ohad Levy"
  s.email = "ohadlevy@gmail.com"
  s.homepage = "https://theforeman.org/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Foreman Proxy Agent, manage remote DHCP, DNS, TFTP and Puppet servers"
  s.files = (Dir.glob("{bin,public,config,views,lib,modules}/**/*") + ["VERSION"])
  s.executables << 'smart-proxy'
  s.require_paths = ["lib", "modules"]
  s.test_files = Dir.glob("{test}/**/*test.rb")
  s.license = 'GPL-3.0'
  s.extra_rdoc_files = ["README.md"]
  s.required_ruby_version = '>= 2.5'
  s.add_dependency 'json'
  s.add_dependency 'logging'
  s.add_dependency 'rack', '>= 1.3'
  s.add_dependency 'sinatra'
  s.description = <<~EOF
    Foreman Proxy is used via The Foreman Project, it allows Foreman to manage
    Remote DHCP, DNS, TFTP and Puppet servers via a REST API
  EOF
end
