if RUBY_PLATFORM !~ /mingw/
  puts "To install this service on Unix please create a startup script"
  exit
end

require 'rubygems'
require 'highline/import'
require 'win32/service'
require 'rbconfig' if RUBY_VERSION < '1.9'

include Win32
include RbConfig

executable = Pathname.new(__FILE__).dirname.parent.join("bin", "smart-proxy-win-service")
executable = executable.realpath.to_s.tr('/', '\\')
working_dir = Pathname.new(__FILE__).dirname.parent.realpath
ruby = File.join(CONFIG['bindir'], 'ruby').tr('/', '\\')
cmd  = "#{ruby} -C #{working_dir} \"#{executable}\""
puts "Installing #{cmd} as a service"

default_user = ENV["USERNAME"]
default_user = ENV["USERDOMAIN"] + '\\' + default_user if ENV["USERDOMAIN"]

puts "This service must run as a user with permission to execute the netsh dhcp script"
puts 'The acount can be local or a domain account. If it is a domain account then use the domain\account syntax'
user  = ask("Run this service as this user? ") {|u| u.default = default_user}
pass1 = ask("Enter the user's password ") {|p| p.echo = "x"}

begin
  Service.stop("smart proxy")   rescue nil
  Service.delete("smart proxy") rescue nil
  Service.create(
    :service_name       =>'smart proxy',
    :host               => nil,
    :service_type       => Service::WIN32_OWN_PROCESS,
    :description        => 'Foreman Smart Proxy',
    :start_type         => Service::AUTO_START,
    :error_control      => Service::ERROR_NORMAL,
    :binary_path_name   => cmd,
    :service_start_name => user,
    :password           => pass1,
    :display_name       => 'Foreman Smart Proxy'
   )
   Service.start('smart proxy')
rescue => e
  puts "There was a problem registering the service: " + e.message
  puts 'Check log file for details'
 end

