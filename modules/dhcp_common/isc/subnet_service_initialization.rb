module Proxy::DHCP::CommonISC
  module IscSubnetServiceInitialization
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

            service.add_host(record.subnet_address, record)
          when Proxy::DHCP::Lease
            if record.state == "free" || (record.options[:next_state] == "free" && record.ends && record.ends < Time.now)
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

