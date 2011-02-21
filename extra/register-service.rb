#!c:\ruby187\bin\ruby
if PLATFORM !~ /mingw/
  puts "To install this service on Unix please create a startup script"
else
  require 'rubygems'
  require 'highline/import'
  require 'win32/service'
  require 'rbconfig'
  include Win32
  include Config

  executable = Pathname.new(__FILE__).dirname.parent.join("bin", "smart-proxy")
  executable = executable.realpath
  ruby = File.join(CONFIG['bindir'], 'ruby').tr('/', '\\')
  cmd  = ruby + ' "' + executable.to_s.tr('/', '\\') + '"'
  puts "Installing #{cmd} as a service"
  cmd += ' --service'

  default_user = ENV["USERNAME"]
  default_user = ENV["USERDOMAIN"] + '\\' + default_user if ENV["USERDOMAIN"]

  puts "This service must run as a user with permission to execute the netsh dhcp script"
  puts 'The acount can be local or a domain account. If it is a domain account then use the domain\account syntax'
  user  = ask("Run this service as this user? ") {|user| user.default = default_user}
  pass1 = ask("Enter the user's password ") {|pass1| pass1.echo = "x"}
  pass2 = ask("Reenter the password "){|pass2| pass2.echo = "x"}
  unless pass1 == pass2
    print "Passwords did not match!"
    exit 1
  end

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
end
