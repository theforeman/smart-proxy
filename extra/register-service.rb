if RUBY_PLATFORM !~ /mingw/
  puts "To install this service on Unix please create a startup script"
  exit
end

require 'rubygems'
require 'highline/import'
require 'win32/service'

include Win32
include RbConfig

executable = Pathname.new(__FILE__).dirname.parent.join("bin", "smart-proxy-win-service")
executable = executable.realpath.to_s.tr('/', '\\')
working_dir = Pathname.new(__FILE__).dirname.parent.realpath
ruby = File.join(CONFIG['bindir'], 'ruby').tr('/', '\\')
cmd  = "#{ruby} -C #{working_dir} \"#{executable}\""
puts "Installing #{cmd} as a service"

default_user         = ENV["USERNAME"]
default_user         = ENV["USERDOMAIN"] + '\\' + default_user if ENV["USERDOMAIN"]
default_service_name = 'smart proxy'

puts "This service must be run under an account that is a member of 'DHCP Administrators' group"
puts 'The account can be local or a domain account. If it is a domain account then use the domain\account syntax'
service_name = ask("Enter the name of the service. ")  { |s| s.default = default_service_name }
user         = ask("Enter the user to run the service as: ") { |u| u.default = default_user }
pass1        = ask("Enter the user's password. ") { |p| p.echo = "x" }

description = 'Foreman Smart Proxy'
description += " (#{service_name})" unless service_name == default_service_name

begin
  Service.stop(service_name)   rescue nil
  Service.delete(service_name) rescue nil
  Service.create(
    :service_name       => service_name,
    :host               => nil,
    :service_type       => Service::WIN32_OWN_PROCESS,
    :description        => description,
    :start_type         => Service::AUTO_START,
    :error_control      => Service::ERROR_NORMAL,
    :binary_path_name   => cmd,
    :service_start_name => user,
    :password           => pass1,
    :display_name       => description
  )
  Service.start(service_name)
rescue => e
  puts "There was a problem registering the service: " + e.message
  puts 'Check log file for details'
end
