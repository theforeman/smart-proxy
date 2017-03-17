require 'dhcp_common/isc/subnet_service_initialization'

module Proxy::DHCP
  module ISC
    class IscStateChangesObserver
      include ::Proxy::DHCP::CommonISC::IscSubnetServiceInitialization
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

      attr_reader :service, :leases_file, :config_file, :events, :event_loop_active, :worker

      def initialize(config_file, leases_file, subnet_service, events = Events.new)
        @config_file = config_file
        @leases_file = leases_file
        @service = subnet_service
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
          load_subnets
          update_subnet_service_with_dhcp_records(config_file.hosts_and_leases)
          update_subnet_service_with_dhcp_records(leases_file.hosts_and_leases)
        end
      end

      def do_leases_modified
        service.group_changes { update_subnet_service_with_dhcp_records(leases_file.hosts_and_leases) }
      end

      def do_leases_recreated
        service.group_changes do
          config_file.close rescue nil
          leases_file.close rescue nil

          service.clear

          load_subnets
          update_subnet_service_with_dhcp_records(config_file.hosts_and_leases)
          update_subnet_service_with_dhcp_records(leases_file.hosts_and_leases)
        end
      end

      def do_stop
        config_file.close rescue nil
        leases_file.close rescue nil
      end

      def load_subnets
        service.add_subnets(*config_file.subnets)
      end
    end
  end
end
