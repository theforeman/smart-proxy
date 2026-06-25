# frozen_string_literal: true

require 'dhcp_common/server'
require 'resolv'

module Proxy
  module DHCP
    module KeaApi
      # The main provider class for the `dhcp_kea_api` module. This class inherits
      # from the Foreman Smart Proxy's core `DHCP::Server` and implements the
      # Kea-specific logic for adding and deleting DHCP reservations and leases.
      class Provider < ::Proxy::DHCP::Server
        attr_reader :subnet_service, :client

        # Initialises the Kea API provider.
        #
        # @param subnet_service [Proxy::DHCP::KeaApi::SubnetService] The service that manages the in-memory cache of DHCP data.
        # @param client [Proxy::DHCP::KeaApi::Client] The client for communicating with the Kea API.
        # @param free_ips [Proxy::DHCP::FreeIps] The service that tracks recently suggested IPs to prevent race conditions.
        def initialize(subnet_service, client, free_ips)
          @subnet_service = subnet_service
          @client = client
          subnet_service.load!
          super('localhost', nil, subnet_service, free_ips)
        end

        # Creates a new DHCP reservation in Kea.
        #
        # @param options [Hash] A hash containing the details for the new reservation.
        # @return [Proxy::DHCP::Reservation] The created reservation object.
        def add_record(options = {})
          logger.debug "DHCP options received from Foreman: #{options.inspect}"
          record = super

          reservation_args = build_base_reservation_args(record)
          add_boot_and_server_options(reservation_args, options)

          option_data = build_option_data(options)
          reservation_args['option-data'] = option_data unless option_data.empty?

          @client.post_command('dhcp4', 'reservation-add', { reservation: reservation_args })
          begin
            subnet_service.add_host(record.subnet.network, record)
          rescue StandardError => e
            logger.error "Cache update failed after successful reservation-add for MAC #{record.mac}. " \
                         "Kea and cache are out of sync: #{e.message}"
            raise
          end

          logger.info "Successfully added reservation for MAC #{record.mac} and IP #{record.ip}"
          record
        end

        # Deletes a DHCP record from Kea. Handles both reservations and leases.
        #
        # @param record [Proxy::DHCP::Reservation, Proxy::DHCP::Lease] The record to be deleted.
        # @return [Proxy::DHCP::Record] The object that was successfully deleted.
        # @raise [Proxy::DHCP::Error] if the record type is unsupported, the corresponding
        #   Kea subnet-id cannot be found, or the API call fails.
        def del_record(record)
          logger.debug "Deleting record: #{record.inspect}"

          if record.is_a?(::Proxy::DHCP::Reservation)
            del_reservation(record)
          elsif record.is_a?(::Proxy::DHCP::Lease)
            del_lease(record)
          else
            raise Proxy::DHCP::Error, "Cannot delete unsupported record type: #{record.class.name}"
          end

          record
        end

        # Loads subnet-level DHCP options from the cached Kea configuration.
        #
        # @param subnet [Proxy::DHCP::Subnet] The subnet to load options for.
        # @return [void]
        def load_subnet_options(subnet)
          opts = @subnet_service.subnet_options[subnet.network]
          return unless opts

          apply_boot_subnet_options(subnet, opts)
          apply_mapped_subnet_options(subnet, opts)
        end

        private

        # Applies the boot/server fields, which are top-level Kea config fields
        # rather than `option-data` entries (so they are not in OPTION_MAP).
        #
        # @param subnet [Proxy::DHCP::Subnet] The subnet to modify.
        # @param opts [Hash] The cached options hash.
        # @return [void]
        def apply_boot_subnet_options(subnet, opts)
          subnet.options[:nextServer] = opts['next-server'] if opts['next-server']
          subnet.options[:filename] = opts['boot-file-name'] if opts['boot-file-name']
        end

        # Applies every `option-data`-derived subnet option using OPTION_MAP as the
        # single source of truth for the Kea-name -> Foreman-key (and list) mapping.
        #
        # @param subnet [Proxy::DHCP::Subnet] The subnet to modify.
        # @param opts [Hash] The cached options hash.
        # @return [void]
        def apply_mapped_subnet_options(subnet, opts)
          SubnetService::OPTION_MAP.each do |kea_name, mapping|
            value = opts[kea_name]
            next unless value

            subnet.options[mapping[:key]] = mapping[:list] ? split_option(value) : value
          end
        end

        # Splits a comma-separated option string into a trimmed array.
        #
        # @param value [String] The comma-separated string.
        # @return [Array<String>] The split and stripped values.
        def split_option(value)
          value.split(',').map(&:strip)
        end

        # Deletes a reservation from Kea by MAC address.
        #
        # @param record [Proxy::DHCP::Reservation] The reservation to delete.
        # @return [void]
        def del_reservation(record)
          subnet_id = find_subnet_id!(record.subnet.network)

          args = {
            'subnet-id': subnet_id,
            'identifier-type': 'hw-address',
            'identifier' => record.mac
          }

          @client.post_command('dhcp4', 'reservation-del', args)
          begin
            subnet_service.delete_host(record)
          rescue StandardError => e
            logger.error "Cache update failed after successful reservation-del for MAC #{record.mac}. " \
                         "Kea and cache are out of sync: #{e.message}"
            raise
          end

          logger.info "Successfully deleted reservation for MAC #{record.mac} and IP #{record.ip}"
        end

        # Deletes a lease from Kea by IP address.
        #
        # @param record [Proxy::DHCP::Lease] The lease to delete.
        # @return [void]
        def del_lease(record)
          subnet_id = find_subnet_id!(record.subnet.network)

          args = {
            'subnet-id': subnet_id,
            'ip-address': record.ip
          }

          @client.post_command('dhcp4', 'lease4-del', args)
          begin
            subnet_service.delete_lease(record)
          rescue StandardError => e
            logger.error "Cache update failed after successful lease4-del for IP #{record.ip}. " \
                         "Kea and cache are out of sync: #{e.message}"
            raise
          end

          logger.info "Successfully deleted lease for IP #{record.ip}"
        end

        # Looks up the Kea subnet-id for a network address, raising if not found.
        #
        # @param network [String] The subnet network address.
        # @return [Integer] The Kea subnet-id.
        # @raise [Proxy::DHCP::Error] if the subnet-id is not in the map.
        def find_subnet_id!(network)
          subnet_id = @subnet_service.kea_id_map[network]
          raise Proxy::DHCP::Error, "Unable to find Kea subnet-id for network #{network}" unless subnet_id

          subnet_id
        end

        # Builds the initial hash of arguments required for a Kea reservation.
        #
        # @param record [Proxy::DHCP::Reservation] The reservation object from the parent class.
        # @return [Hash] A hash containing the base arguments for the Kea API.
        def build_base_reservation_args(record)
          subnet_id = find_subnet_id!(record.subnet.network)

          {
            'subnet-id': subnet_id,
            'ip-address': record.ip,
            'hw-address': record.mac,
            hostname: record.name
          }
        end

        # Adds next-server and boot-file-name options to the reservation arguments hash.
        #
        # @param reservation_args [Hash] The hash of arguments to be modified.
        # @param options [Hash] The original options hash from Foreman.
        # @return [void]
        def add_boot_and_server_options(reservation_args, options)
          next_server_value = options['nextServer']
          reservation_args[:'next-server'] = resolve_hostname(next_server_value) unless next_server_value.to_s.empty?

          reservation_args[:'boot-file-name'] = options['filename'] unless options['filename'].to_s.empty?
        end

        # Resolves a hostname to an IP address. If the provided string is already
        # an IP, it is returned directly.
        #
        # @param hostname [String] The hostname or IP address string to resolve.
        # @return [String] The resolved IPv4 address.
        # @raise [Proxy::DHCP::Error] if the hostname cannot be resolved.
        def resolve_hostname(hostname)
          return hostname if hostname =~ Regexp.union(Resolv::IPv4::Regex)

          Resolv.getaddress(hostname)
        rescue Resolv::ResolvError => e
          raise Proxy::DHCP::Error, "Could not resolve next-server hostname '#{hostname}': #{e.message}"
        end

        # Builds the array of DHCP options (e.g. routers, ntp-servers, dns-servers) for the reservation.
        #
        # @param options [Hash] The original options hash from Foreman.
        # @return [Array<Hash>] An array of option hashes for the Kea API.
        def build_option_data(options)
          option_data = []
          SubnetService::OPTION_MAP.each do |kea_name, mapping|
            add_dhcp_option(option_data, kea_name, options[mapping[:key].to_s])
          end
          option_data
        end

        # A helper to add a DHCP option to the data array if the value exists.
        #
        # @param option_data [Array<Hash>] The array of options to be modified.
        # @param name [String] The name of the DHCP option (e.g. 'routers').
        # @param value [String, Array] The value of the option.
        # @return [void]
        def add_dhcp_option(option_data, name, value)
          return if value.nil? || (value.respond_to?(:empty?) && value.empty?)

          option_data << { name: name, data: Array(value).join(',') }
        end
      end
    end
  end
end
