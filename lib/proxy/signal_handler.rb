require 'proxy/log'

class Proxy::SignalHandler
  include ::Proxy::Log

  def self.install_traps(servers)
    handler = new
    handler.install_ttin_trap unless RUBY_PLATFORM =~ /mingw/
    handler.install_int_trap(servers)
    handler.install_term_trap(servers)
    handler.install_usr1_trap unless RUBY_PLATFORM =~ /mingw/
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

  def install_int_trap(servers)
    trap(:INT) do
      servers.each do |server|
        server.shutdown
      end
      exit(0)
    end
  end

  def install_term_trap(servers)
    trap(:TERM) do
      servers.each do |server|
        server.shutdown
      end
      exit(0)
    end
  end

  def install_usr1_trap
    trap(:USR1) do
      ::Proxy::LogBuffer::Decorator.instance.roll_log
    end
  end
end
