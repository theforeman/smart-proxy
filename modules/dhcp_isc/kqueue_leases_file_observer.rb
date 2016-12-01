require 'rb-kqueue'

module ::Proxy::DHCP::ISC
  class KqueueLeasesFileObserver
    include ::Proxy::Log

    attr_reader :observer, :leases_filename

    def initialize(state_changes_observer, leases_path)
      @observer = state_changes_observer
      @leases_filename = File.expand_path(leases_path)
    end

    def monitor_leases
      @queue = KQueue::Queue.new

      watcher_proc = lambda do |event|
        event.flags.each do |flag|
          case flag
            when :write
              logger.debug "caught :write event on #{leases_filename}."
              observer.leases_modified
            when :delete
              logger.debug "caught :delete event on #{leases_filename}."
              observer.leases_recreated
              event.watcher.delete!
              @queue.watch_file(leases_filename, :write, :delete, &watcher_proc)
          end
        end
      end

      @queue.watch_file(leases_filename, :write, :delete, &watcher_proc)
      @queue.run
    end

    def start
      observer.start
      Thread.new { monitor_leases }
    end

    def stop
      @queue.stop unless @queue.nil?
      observer.stop
    end
  end
end
