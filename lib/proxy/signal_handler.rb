require 'proxy/log'

class Proxy::SignalHandler
  include ::Proxy::Log

  def self.install_traps
    handler = new
    handler.install_ttin_trap unless RUBY_PLATFORM =~ /mingw/
    handler.install_int_trap
    handler.install_term_trap
  end

  def install_ttin_trap
    # logger can't be accessed from trap context
    trap(:TTIN) do
      puts "Starting thread dump for current Ruby process"
      puts "============================================="
      puts ""
      Thread.list.each do |thread|
        puts "Thread TID-#{thread.object_id}"
        puts thread.backtrace
        puts ""
      end
    end
  end

  def install_int_trap
    if Rack.release < '1.6.4'
      # Rack installs its own trap; Sleeping for 5 secs insures we overwrite it with our own
      Thread.new do
        sleep 5
        begin
          trap(:INT) { exit(0) }
        rescue Exception => e
          logger.warn "Unable to overwrite interrupt trap: #{e}"
        end
      end
    end
  end

  def install_term_trap
    trap(:TERM) { exit(0) }
  end
end
