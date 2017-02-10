require 'dhcp_common/isc/subnet_service_initialization'

module Proxy::DHCP
  module ISC
    class IscStateChangesObserver
      include ::Proxy::Log

      class Events
        attr_accessor :m, :last_event

        STARTED = :started
        STOPPED = :stopped
        MODIFIED = :modified
        RECREATED = :recreated
        NONE = :none

        def initialize
          @m = Monitor.new
          @last_event = NONE
        end

        def started
          push(STARTED)
        end

        def stopped
          push(STOPPED)
        end

        def modified
          push(MODIFIED)
        end

        def recreated
          push(RECREATED)
        end

        def push(an_event)
          m.synchronize do
            case an_event
            when STARTED
              return false unless @last_event == NONE
              @last_event = STARTED
            when STOPPED
              @last_event = STOPPED
            when MODIFIED
              return false unless @last_event == NONE
              @last_event = MODIFIED
            when RECREATED
              return false if @last_event != NONE && @last_event != MODIFIED
              @last_event = RECREATED
            else
              return false
            end
          end
          return true
        end

        def pop
          @m.synchronize do
            to_return = @last_event
            @last_event = NONE
            to_return
          end
        end
      end

      attr_reader :service, :service_initializer, :leases_file_path, :config_file_path, :events, :event_loop_active, :worker

      def initialize(config_file_path, leases_file_path, subnet_service, service_initializer, events = Events.new)
        @config_file_path = config_file_path
        @leases_file_path = leases_file_path
        @service = subnet_service
        @service_initializer = service_initializer
        @events = events
        @event_loop_active = false
      end

      def start
        do_start
        @event_loop_active = true
        @worker = new_worker
        nil
      end

      def stop
        events.stopped
        worker.wakeup unless worker.nil?
      end

      def leases_modified
        raise "IscStateChangesObserver worker thread hasn't been started" if worker.nil?
        events.modified
        worker.wakeup
      end

      def leases_recreated
        raise "IscStateChangesObserver worker thread hasn't been started" if worker.nil?
        events.recreated
        worker.wakeup
      end

      def event_loop
        while event_loop_active
          case events.pop
          when Events::MODIFIED
            do_leases_modified
          when Events::RECREATED
            do_leases_recreated
          when Events::STOPPED
            do_stop
            @event_loop_active = false
          else
            pause
          end
        end
      end

      def new_worker
        Thread.new { event_loop }
      end

      def pause
        Thread.stop
      end

      def do_start
        service.group_changes do
          load_configuration_file
          load_leases_file
        end
      end

      def do_leases_modified
        service.group_changes { load_leases_file }
      end

      def do_leases_recreated
        service.group_changes do
          close_leases_file
          service.clear
          load_configuration_file
          load_leases_file
        end
      end

      def do_stop
        close_leases_file
      end

      def load_configuration_file
        service_initializer.load_configuration_file(read_config_file, config_file_path)
      end

      def load_leases_file
        service_initializer.load_leases_file(read_leases_file, leases_file_path)
      end

      def read_leases_file
        @leases_file ||= File.open(File.expand_path(leases_file_path), "r")
        @leases_file.read
      end

      def close_leases_file
        @leases_file.close unless @leases_file.nil?
        @leases_file = nil
      end

      def read_config_file
        File.read(File.expand_path(config_file_path))
      end
    end
  end
end
