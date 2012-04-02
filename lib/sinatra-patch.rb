require "sinatra/base"
require "openssl"
require "webrick/https"
require "daemon" unless PLATFORM =~/mingw/
module Sinatra
  class Base
    # Run the Sinatra app as a self-hosted server using
    # Thin, Mongrel or WEBrick (in that order)
    def self.run!(options={})
      set options
      handler      = detect_rack_handler
      handler_name = handler.name.gsub(/.*::/, '')

      # Hack to cope with renamed options in Sinatra 1.0.a
      bind = host if VERSION == '1.0.a'

      puts "Starting Foreman Proxy on #{port} using #{handler_name}" unless handler_name =~/cgi/i

      FileUtils.mkdir_p(File.join(APP_ROOT, 'tmp/pids'))

      if SETTINGS.daemon and PLATFORM !~ /mingw/
        Process.daemon(true)
        if SETTINGS.daemon_pid.nil?
          pid = "#{APP_ROOT}/tmp/pids/server.pid"
        else
          pid = "#{SETTINGS.daemon_pid}"
        end
        begin
          puts "Writing to #{pid}"
          File.open(pid, 'w'){ |f| f.write(Process.pid) }
          at_exit { File.delete(pid) if File.exist?(pid) }
        rescue Exception => e
          puts "== Error writing pid file #{pid}!"
        end
      end
      handler.run self, {:Host => bind, :Port => port}.merge(@ssl_options) do |server|
        [:INT, :TERM].each { |sig| trap(sig) {
          server.respond_to?(:stop) ? server.stop : quit!(server, handler_name)
        } }
        set :running, true
      end
    rescue Errno::EADDRINUSE => e
      puts "== Someone is already performing on port #{port}!"
    end
  end
end
