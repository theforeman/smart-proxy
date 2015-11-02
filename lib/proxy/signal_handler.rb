require 'proxy/log'

class Proxy::SignalHandler
  def self.install_ttin_trap
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
end
