require 'rb-inotify'

module ::Proxy::DHCP::ISC
  class InotifyLeasesFileObserver
    include ::Proxy::Log

    attr_reader :observer, :leases_filename

    def initialize(state_changes_observer, leases_path)
      @observer = state_changes_observer
      @leases_filename = File.expand_path(leases_path)
    end

    def monitor_leases
      @notifier = INotify::Notifier.new
      @notifier.watch(File.dirname(leases_filename), :modify, :moved_to) do |event|
        if event.absolute_name == leases_filename
          event.flags.each do |flag|
            case flag
            when :modify
              logger.debug "caught :modify event on #{event.absolute_name}."
              observer.leases_modified
            when :moved_to
              logger.debug "caught :moved_to event on #{event.absolute_name}."
              observer.leases_recreated
            end
          end
        end
      end

      @notifier.run
    rescue INotify::QueueOverflowError => e
      logger.warn "Queue overflow occured when monitoring #{leases_filename}, restarting monitoring", e
      observer.leases_recreated
      retry
    rescue Exception => e
      logger.error "Error occured when monitoring #{leases_filename}", e
    end

    def start
      observer.monitor_started
      Thread.new { monitor_leases }
    end

    def stop
      @notifier.stop unless @notifier.nil?
      observer.monitor_stopped
    end
  end
end
