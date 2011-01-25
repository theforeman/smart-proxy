require "sinatra/base"
require "openssl"
require "webrick/https"
require "daemon"
module Sinatra
  class Base
    # Run the Sinatra app as a self-hosted server using
    # Thin, Mongrel or WEBrick (in that order)
    def self.run!(options={},ssl_options={})
      set options
      handler      = detect_rack_handler
      handler_name = handler.name.gsub(/.*::/, '')
      puts "Starting Foreman Proxy on #{port} using #{handler_name}" unless handler_name =~/cgi/i

      FileUtils.mkdir_p(File.join(APP_ROOT, 'tmp/pids'))

      if SETTINGS.daemon
        Process.daemon(true)
        pid = "#{APP_ROOT}/tmp/pids/server.pid"
        File.open(pid, 'w'){ |f| f.write(Process.pid) }
        at_exit { File.delete(pid) if File.exist?(pid) }
      end
      handler.run self, {:Host => bind, :Port => port}.merge(ssl_options) do |server|
        [:INT, :TERM].each { |sig| trap(sig) { quit!(server, handler_name) } }
        set :running, true
      end
    rescue Errno::EADDRINUSE => e
      puts "== Someone is already performing on port #{port}!"
    end
  end
end
