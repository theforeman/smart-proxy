module Proxy::DHCP::CommonISC
  class IscSubnetServiceInitialization
    attr_reader :parser, :subnet_service

    def initialize(subnet_service, parser)
      @subnet_service = subnet_service
      @parser = parser
    end

    def load_configuration_file(file_content, file_path = "dhcpd.conf")
      subnets, records, _, _ = parser.subnets_hosts_and_leases(file_content, file_path)
      update_subnet_service_with_subnet_records(subnet_service, subnets)
      update_subnet_service_with_dhcp_records(subnet_service, records)
    end

    def load_leases_file(file_content, file_path = "dhcpd.leases")
      _, records, _, _ = parser.subnets_hosts_and_leases(file_content, file_path) # no subnet information in leases file
      update_subnet_service_with_dhcp_records(subnet_service, records)
    end

    def update_subnet_service_with_subnet_records(service, subnets_to_add)
      subnets_to_add.each {|record| service.add_subnet(to_subnet(record))}
    end

    def update_subnet_service_with_dhcp_records(service, records_to_add)
      records_to_add.each do |record|
        case record
        when Proxy::DHCP::CommonISC::ConfigurationParser::Host
          if record.node_attributes[:deleted]
            existing = service.find_host_by_hostname(record.name)
            service.delete_host(existing) if existing
            next
          end
          reservation_to_add = to_reservation(record)
          next if reservation_to_add.nil?
          if (dupe = service.find_host_by_mac(reservation_to_add.subnet_address, reservation_to_add.mac))
            service.delete_host(dupe)
          end
          service.add_host(reservation_to_add.subnet_address, reservation_to_add)
        when Proxy::DHCP::CommonISC::ConfigurationParser::Lease
          lease = to_lease(record)
          next if lease.nil?

          if lease.state == "free" || (lease.options[:next_state] == "free" && lease.ends && lease.ends < Time.now.utc)
            to_delete = service.find_lease_by_ip(lease.subnet_address, lease.ip)
            service.delete_lease(to_delete) if to_delete
            next
          end

          if (dupe = service.find_lease_by_mac(lease.subnet_address, lease.mac))
            service.delete_lease(dupe)
          end
          if (dupe = service.find_lease_by_ip(lease.subnet_address, lease.ip))
            service.delete_lease(dupe)
          end

          service.add_lease(lease.subnet_address, lease)
        end
      end
    end

    def to_subnet(parsed_subnet)
      network = parsed_subnet.subnet_address
      netmask = parsed_subnet.subnet_mask

      attributes_only = parsed_subnet.node_attributes.inject({}) do |all, current|
        key, value = process_dhcpd_attributes(current[0], current[1])
        all[key] = value
        all
      end

      options_and_attributes = parsed_subnet.dhcp_options.inject(attributes_only) do |all, current|
        key, values = process_dhcpd_option(current[0], current[1])
        all[key] = values
        all
      end

      Proxy::DHCP::Subnet.new(network, netmask, options_and_attributes)
    end

    def to_reservation(parsed_host)
      name = parsed_host.name
      ip_address = parsed_host.node_attributes.delete(:fixed_address)
      mac_address = parsed_host.node_attributes.delete(:hardware_address)
      return nil if ip_address.nil? || ip_address.empty? || mac_address.nil? || mac_address.empty?

      subnet = subnet_service.find_subnet(ip_address)
      return nil if subnet.nil?

      attributes_only = parsed_host.node_attributes.inject({}) do |all, current|
        key, value = process_dhcpd_attributes(current[0], current[1])
        all[key] = value
        all
      end

      default_attributes = {
        :hostname => name,
        :deleteable => false,
      }

      options_and_attributes = parsed_host.dhcp_options.inject(default_attributes.merge(attributes_only)) do |all, current|
        key, values = process_dhcpd_option(current[0], current[1])
        all[key] = values
        all
      end

      Proxy::DHCP::Reservation.new(name, ip_address, mac_address, subnet, options_and_attributes)
    end

    def to_lease(parsed_lease)
      ip_address = parsed_lease.ip_address
      mac_address = parsed_lease.node_attributes.delete(:hardware_address)
      subnet = subnet_service.find_subnet(ip_address)
      starts = parsed_lease.node_attributes.delete(:starts)
      ends = parsed_lease.node_attributes.delete(:ends)
      state = parsed_lease.node_attributes.delete(:binding_state)

      return nil if mac_address.nil? || mac_address.empty? || subnet.nil?

      attributes_only = parsed_lease.node_attributes.inject({}) do |all, current|
        key, value = process_dhcpd_attributes(current[0], current[1])
        all[key] = value
        all
      end

      options_and_attributes = parsed_lease.dhcp_options.inject(attributes_only) do |all, current|
        key, values = process_dhcpd_option(current[0], current[1])
        all[key] = values
        all
      end

      Proxy::DHCP::Lease.new(nil, ip_address, mac_address, subnet, starts, ends, state, options_and_attributes)
    end

    def process_dhcpd_attributes(name, value)
      return [:deleteable, true] if name == :dynamic
      return [:next_state, value] if name == :next_binding_state
      return [:vendor, 'sun'] if name == :vendor_option_space # no other namespaces will be returned from the parser
      [name, value]
    end

    #
    # values are an array of arrays, i.e.: [["first", "second"], ["third", "fourth"]]
    # this is required in order to represent record-type dhcp options
    # please see dhcpd-options(5) for more detailed information
    #
    require 'resolv'
    def process_dhcpd_option(name, values)
      case name
        when 'routers'
          [:routers, values.flatten.map {|r| strip_quotes(r)}]
        when 'domain-name-servers'
          [:domain_name_servers, values.flatten.map {|r| strip_quotes(r)}]
        when 'next-server', 'server.next-server'
          without_quotes = strip_quotes(values.flatten.first)
          return [:nextServer, without_quotes] if without_quotes.match(Resolv::IPv4::Regex)
          [:nextServer, hex2ip(without_quotes)]
        when 'filename', 'server.filename'
          [:filename, strip_quotes(values.flatten.first)]
        when 'host-name'
          [:hostname, strip_quotes(values.flatten.first)]
        when 'SUNW.root-server-ip-address'
          [:root_server_ip, strip_quotes(values.flatten.first)]
        when 'SUNW.root-server-hostname'
          [:root_server_hostname, strip_quotes(values.flatten.first)]
        when 'SUNW.root-path-name'
          [:root_path_name, strip_quotes(values.flatten.first)]
        when 'SUNW.install-server-ip-address'
          [:install_server_ip, strip_quotes(values.flatten.first)]
        when 'SUNW.install-server-hostname'
          [:install_server_name, strip_quotes(values.flatten.first)]
        when 'SUNW.install-path'
          [:install_path, strip_quotes(values.flatten.first)]
        when 'SUNW.sysid-config-file-server'
          [:sysid_server_path, strip_quotes(values.flatten.first)]
        when 'SUNW.JumpStart-server'
          [:jumpstart_server_path, strip_quotes(values.flatten.first)]
        else
          [name.tr('.', '_').tr('-', '_').to_sym, values.map {|vv| vv.map{|v| strip_quotes(v)}}]
        #TODO: check if adding a new reservation with omshell for a free lease still
        #generates a conflict
      end
    end

    def strip_quotes(a_str)
      return a_str[1..-2] if a_str.start_with?('"', "'")
      a_str
    end

    def hex2ip hex
      hex.split(":").map{|h| h.to_i(16).to_s}.join(".")
    end
  end
end
