module Proxy::DHCP
  module ISC
    class IscStateChangesObserver
      include ::Proxy::Log

      attr_reader :service, :leases_file, :config_file

      def initialize(config_file, leases_file, subnet_service)
        @config_file = config_file
        @leases_file = leases_file
        @service = subnet_service
      end

      def monitor_started
        service.group_changes do
          load_subnets
          update_subnet_service_with_dhcp_records(config_file.hosts_and_leases)
          update_subnet_service_with_dhcp_records(leases_file.hosts_and_leases)
        end
      end

      def leases_modified
        service.group_changes { update_subnet_service_with_dhcp_records(leases_file.hosts_and_leases) }
      end

      def leases_recreated
        service.group_changes do
          config_file.close rescue nil
          leases_file.close rescue nil

          service.clear

          load_subnets
          update_subnet_service_with_dhcp_records(config_file.hosts_and_leases)
          update_subnet_service_with_dhcp_records(leases_file.hosts_and_leases)
        end
      end

      def monitor_stopped
        config_file.close rescue nil
        leases_file.close rescue nil
      end

      def load_subnets
        service.add_subnets(*config_file.subnets)
      end

      def update_subnet_service_with_dhcp_records(records)
        records.each do |record|
          case record
            when Proxy::DHCP::DeletedReservation
              record = service.find_host_by_hostname(record.name)
              service.delete_host(record) if record
              next
            when Proxy::DHCP::Reservation
              if dupe = service.find_host_by_mac(record.subnet_address, record.mac)
                service.delete_host(dupe)
              end
              if dupe = service.find_host_by_ip(record.subnet_address, record.ip)
                service.delete_host(dupe)
              end

              service.add_host(record.subnet_address, record)
            when Proxy::DHCP::Lease
              if record.options[:state] == "free" || (record.options[:next_state] == "free" && record.options[:ends] && record.options[:ends] < Time.now)
                record = service.find_lease_by_ip(record.subnet_address, record.ip)
                service.delete_lease(record) if record
                next
              end

              if dupe = service.find_lease_by_mac(record.subnet_address, record.mac)
                service.delete_lease(dupe)
              end
              if dupe = service.find_lease_by_ip(record.subnet_address, record.ip)
                service.delete_lease(dupe)
              end

              service.add_lease(record.subnet_address, record)
          end
        end
      end
    end
  end
end
