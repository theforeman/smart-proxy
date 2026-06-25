# frozen_string_literal: true

require 'ipaddr'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet_service'

module Proxy
  module DHCP
    module KeaApi
      # Manages the in-memory cache of DHCP data for the Kea provider.
      #
      # This class is responsible for fetching all subnet, reservation, and lease
      # information from the Kea API. It inherits from the core `DHCP::SubnetService`
      # to get the underlying data structures (e.g. hashes for leases and hosts)
      # and caching logic. Its primary public method, `load!`, orchestrates the
      # population of this cache. It also maintains a mapping of Foreman subnet
      # networks to their internal Kea API subnet IDs.
      class SubnetService < ::Proxy::DHCP::SubnetService
        include Proxy::Log

        # Holds the data fetched during a reload before it is atomically swapped
        # into the live cache. Wraps a throwaway parent SubnetService (for its
        # thread-safe stores and lookup helpers) plus the Kea-specific maps, so
        # the loaders can populate it exactly as they would the live object.
        class Staging
          attr_reader :service, :kea_id_map, :subnet_options

          # @return [void]
          def initialize
            @service = ::Proxy::DHCP::SubnetService.initialized_instance
            @kea_id_map = {}
            @subnet_options = {}
          end
        end

        # Maps Kea option-data names to their Foreman option keys and whether they are lists.
        OPTION_MAP = {
          'routers' => { key: :routers, list: true },
          'domain-name-servers' => { key: :dns_servers, list: true },
          'domain-name' => { key: :domain_name, list: false },
          'ntp-servers' => { key: :ntp_servers, list: true }
        }.freeze

        # A hash mapping a subnet network address (e.g. "192.168.1.0") to its
        # internal Kea API integer ID (e.g. 1). This is crucial for making
        # API calls that require a `subnet-id`.
        attr_reader :kea_id_map

        # A hash mapping a subnet network address to its DHCP options hash.
        # Used by the Provider to serve subnet-level options back to Foreman.
        attr_reader :subnet_options

        # Initialises the SubnetService.
        #
        # @param client [Proxy::DHCP::KeaApi::Client] The client for communicating with the Kea API.
        # @param leases_by_ip [Proxy::MemoryStore] A memory store for leases, passed to the parent class.
        # @param leases_by_mac [Proxy::MemoryStore] A memory store for leases, passed to the parent class.
        # @param reservations_by_ip [Proxy::MemoryStore] A memory store for reservations, passed to the parent class.
        # @param reservations_by_mac [Proxy::MemoryStore] A memory store for reservations, passed to the parent class.
        # @param reservations_by_name [Proxy::MemoryStore] A memory store for reservations, passed to the parent class.
        # @param cache_ttl [Integer] Number of seconds before the cache is considered stale (default: 60).
        # @param managed_subnets [Array<String>, nil] List of CIDR networks to manage. Nil means manage all.
        # @return [void]
        # rubocop:disable Metrics/ParameterLists
        def initialize(client, leases_by_ip, leases_by_mac, reservations_by_ip, reservations_by_mac, reservations_by_name,
                       cache_ttl: 60, managed_subnets: nil)
          @client = client
          @kea_id_map = {}
          @subnet_options = {}
          @cache_ttl = cache_ttl
          @loaded_at = nil
          @reload_mutex = Mutex.new
          @managed_subnets = parse_managed_subnets(managed_subnets)
          super(leases_by_ip, leases_by_mac, reservations_by_ip, reservations_by_mac, reservations_by_name)
        end
        # rubocop:enable Metrics/ParameterLists

        # The main entry point for loading all DHCP data from the Kea server.
        #
        # All Kea API calls populate a fresh, off-to-the-side set of stores
        # (`staging`); only once every fetch has succeeded are the new stores
        # swapped into the live cache under the parent's monitor. This keeps the
        # slow network fetch off the live cache so concurrent readers never see a
        # half-populated state, and leaves the previous cache intact if the fetch
        # fails partway through.
        #
        # @return [true] on success.
        # @raise [Proxy::DHCP::Error] if any part of the loading process fails.
        # @see #load_subnets_and_reservations_from_kea
        # @see #load_leases_from_kea
        # rubocop:disable Naming/PredicateMethod
        def load!
          staging = Staging.new

          load_subnets_and_reservations_from_kea(staging)
          load_reservations_from_database(staging)
          load_leases_from_kea(staging)

          commit(staging)
          true
        end
        # rubocop:enable Naming/PredicateMethod

        # Returns all subnets, refreshing the cache if stale.
        #
        # @return [Array<Proxy::DHCP::Subnet>] All cached subnets.
        def all_subnets
          reload_if_stale!
          super
        end

        # Returns all host reservations, refreshing the cache if stale.
        #
        # @param subnet_address [String, nil] Optional subnet to filter by.
        # @return [Array<Proxy::DHCP::Reservation>] All cached reservations.
        def all_hosts(subnet_address = nil)
          reload_if_stale!
          super
        end

        # Returns all leases, refreshing the cache if stale.
        #
        # @param subnet_address [String, nil] Optional subnet to filter by.
        # @return [Array<Proxy::DHCP::Lease>] All cached leases.
        def all_leases(subnet_address = nil)
          reload_if_stale!
          super
        end

        # Fetches all subnets and their associated reservations from the Kea API.
        # This single `config-get` call is the most efficient way to get all static configuration.
        #
        # @param staging [Staging] The buffer to populate with fetched data.
        # @return [void]
        # @raise [Proxy::DHCP::Error] if the API call fails.
        # @raise [IPAddr::InvalidAddressError] if a subnet address from Kea is invalid.
        # @see Proxy::DHCP::KeaApi::Client#post_command
        def load_subnets_and_reservations_from_kea(staging)
          config = @client.post_command('dhcp4', 'config-get')
          subnets_data = config&.dig('Dhcp4', 'subnet4')
          return unless subnets_data

          subnets_data.each do |subnet_data|
            process_subnet(subnet_data, staging)
          end
        rescue Proxy::DHCP::Error => e
          logger.error "Failed to load subnets and reservations from Kea: #{e.message}"
          raise
        rescue IPAddr::InvalidAddressError => e
          logger.error "Failed to parse subnet from Kea, invalid address found: #{e.message}"
          raise
        end

        # Fetches dynamically added reservations from Kea's hosts-database via
        # `reservation-get-all`. These are not included in `config-get` which only
        # returns static reservations from the config file.
        #
        # @param staging [Staging] The buffer to populate with fetched data.
        # @return [void]
        def load_reservations_from_database(staging)
          return if staging.kea_id_map.empty?

          staging.kea_id_map.each do |network, subnet_id|
            response = @client.post_command('dhcp4', 'reservation-get-all', { 'subnet-id': subnet_id })
            hosts = response&.[]('hosts')
            next unless hosts

            subnet_obj = staging.service.find_subnet(network)
            next unless subnet_obj

            hosts.each do |res_data|
              next if staging.service.find_host_by_mac(network, res_data['hw-address'])

              process_reservation(res_data, subnet_obj, staging)
            end
          end
        rescue Proxy::DHCP::Error => e
          logger.debug "reservation-get-all not available or failed: #{e.message}"
        end

        # Fetches all active leases from the Kea API for the subnets currently in the cache.
        #
        # @param staging [Staging] The buffer to populate with fetched data.
        # @return [void]
        # @raise [Proxy::DHCP::Error] if the API call fails.
        # @see Proxy::DHCP::KeaApi::Client#post_command
        def load_leases_from_kea(staging)
          return if staging.kea_id_map.empty?

          response = @client.post_command('dhcp4', 'lease4-get-all', { subnets: staging.kea_id_map.values })
          return unless response && response['leases']

          response['leases'].each do |lease|
            process_lease(lease, staging)
          end
        rescue Proxy::DHCP::Error => e
          logger.error "Failed to load all leases from Kea: #{e.message}"
          raise
        end

        private

        # Reloads the cache if it is older than the configured TTL. Only one thread
        # performs the reload at a time (single-flight via `try_lock`); other threads
        # that observe a stale cache serve the current snapshot instead of piling on
        # duplicate, concurrent reloads.
        #
        # @return [void]
        def reload_if_stale!
          return unless stale?
          return unless @reload_mutex.try_lock

          begin
            return unless stale? # re-check: another thread may have just reloaded

            logger.debug "Cache TTL (#{@cache_ttl}s) expired, reloading from Kea"
            load!
          ensure
            @reload_mutex.unlock
          end
        end

        # Atomically replaces the live cache with the freshly-staged data. The swap
        # runs under the parent's monitor so that readers (which take the same lock)
        # observe either the entire old cache or the entire new one, never a mix.
        #
        # @param staging [Staging] The fully-populated buffer to promote.
        # @return [void]
        def commit(staging)
          m.synchronize do
            @subnets = staging.service.subnets
            @leases_by_ip = staging.service.leases_by_ip
            @leases_by_mac = staging.service.leases_by_mac
            @reservations_by_ip = staging.service.reservations_by_ip
            @reservations_by_mac = staging.service.reservations_by_mac
            @reservations_by_name = staging.service.reservations_by_name
            @kea_id_map = staging.kea_id_map
            @subnet_options = staging.subnet_options
            @loaded_at = Time.now
          end
        end

        # Checks whether the cache has exceeded its TTL.
        #
        # @return [Boolean] true if the cache needs refreshing.
        def stale?
          return true unless @loaded_at

          (Time.now - @loaded_at) > @cache_ttl
        end

        # Parses the managed_subnets setting into IPAddr objects for matching.
        #
        # @param managed_subnets [Array<String>, String, nil] CIDR networks to manage.
        # @return [Array<IPAddr>, nil] Parsed networks, or nil to manage all.
        def parse_managed_subnets(managed_subnets)
          return nil if managed_subnets.nil?

          subnets = Array(managed_subnets)
          return nil if subnets.empty?

          subnets.map { |cidr| IPAddr.new(cidr) }
        end

        # Checks whether a subnet should be managed by this proxy.
        #
        # @param subnet_addr [String] The network address of the subnet.
        # @return [Boolean] true if the subnet should be managed.
        def managed?(subnet_addr)
          return true unless @managed_subnets

          ip = IPAddr.new(subnet_addr)
          # include? already returns true for an exact match (e.g. a /32 entry), so
          # no separate equality check is needed.
          @managed_subnets.any? { |network| network.include?(ip) }
        end

        # Parses a single subnet hash from the API response, creates the necessary
        # Foreman Subnet and Reservation objects, and adds them to the cache.
        #
        # @param subnet_data [Hash] The hash representing a single subnet from Kea's `config-get` response.
        # @param staging [Staging] The buffer to populate with the parsed subnet.
        # @return [void]
        # @raise [IPAddr::InvalidAddressError] if the subnet string is not a valid IP address.
        def process_subnet(subnet_data, staging)
          ip_object = IPAddr.new(subnet_data['subnet'])
          subnet_addr = ip_object.to_s
          mask = IPAddr.new('255.255.255.255').mask(ip_object.prefix).to_s

          return unless managed?(subnet_addr)

          options = {
            routers: extract_routers(subnet_data),
            range: extract_range(subnet_data)
          }.compact
          subnet = ::Proxy::DHCP::Subnet.new(subnet_addr, mask, options)

          staging.service.add_subnet(subnet)
          staging.kea_id_map[subnet.network] = subnet_data['id']
          staging.subnet_options[subnet.network] = extract_subnet_options(subnet_data)
          logger.info "Loaded subnet #{subnet.network}/#{subnet.netmask} and mapped to Kea ID #{subnet_data['id']}"

          subnet_data['reservations']&.each do |res_data|
            process_reservation(res_data, subnet, staging)
          end
        end

        # Extracts all DHCP options from a subnet into a normalised hash.
        #
        # @param subnet_data [Hash] The hash representing a single subnet.
        # @return [Hash] A hash of option names to their values.
        def extract_subnet_options(subnet_data)
          opts = {}
          option_data = subnet_data['option-data'] || []
          option_data.each do |opt|
            opts[opt['name']] = opt['data']
          end
          opts['next-server'] = subnet_data['next-server'] if meaningful_boot_value?(subnet_data['next-server'])
          opts['boot-file-name'] = subnet_data['boot-file-name'] if meaningful_boot_value?(subnet_data['boot-file-name'])
          opts
        end

        # Returns true when a Kea boot field carries a real value. Kea reports an
        # unset next-server as "0.0.0.0" and an unset boot-file-name as "", which
        # are placeholders that must not be round-tripped back to Foreman as if a
        # user had configured them (doing so triggers spurious DHCP rebuilds).
        #
        # @param value [String, nil] The raw value from Kea.
        # @return [Boolean] true if the value is present and not a placeholder.
        def meaningful_boot_value?(value)
          !value.nil? && !value.to_s.strip.empty? && value != '0.0.0.0'
        end

        # Extracts and formats the router data from a subnet's options.
        #
        # @param subnet_data [Hash] The hash representing a single subnet.
        # @return [Array<String>, nil] An array of router IP addresses, or nil if none are found.
        def extract_routers(subnet_data)
          router_opt = subnet_data['option-data']&.find { |opt| opt['name'] == 'routers' }
          data = router_opt&.[]('data')
          data&.split(',')&.map(&:strip)
        end

        # Extracts the IP range from a subnet's first pool.
        #
        # @param subnet_data [Hash] The hash representing a single subnet.
        # @return [Array<String>, nil] A two-element array containing the start and end of the range, or nil.
        def extract_range(subnet_data)
          pool_string = subnet_data.dig('pools', 0, 'pool')
          pool_string&.split('-')&.map(&:strip)
        end

        # Creates a Foreman Reservation object from Kea data and adds it to the cache.
        # Includes option-data, next-server, and boot-file-name so that Foreman can
        # round-trip these values when querying existing reservations.
        #
        # @param res_data [Hash] The hash representing a single reservation.
        # @param subnet [Proxy::DHCP::Subnet] The subnet object this reservation belongs to.
        # @param staging [Staging] The buffer to populate with the parsed reservation.
        # @return [void]
        def process_reservation(res_data, subnet, staging)
          opts = extract_reservation_options(res_data)
          record = ::Proxy::DHCP::Reservation.new(
            res_data['hostname'], res_data['ip-address'], res_data['hw-address'], subnet, opts
          )
          staging.service.add_host(subnet.network, record)
          logger.debug "Loaded reservation for #{res_data['hw-address']} on subnet #{subnet.network}"
        end

        # Extracts Foreman-compatible options from a Kea reservation hash.
        #
        # @param res_data [Hash] The reservation data from Kea's config-get.
        # @return [Hash] Options hash suitable for Proxy::DHCP::Reservation.
        def extract_reservation_options(res_data)
          opts = {}
          opts[:nextServer] = res_data['next-server'] if meaningful_boot_value?(res_data['next-server'])
          opts[:filename] = res_data['boot-file-name'] if meaningful_boot_value?(res_data['boot-file-name'])
          map_option_data(opts, res_data['option-data'] || [])
          opts
        end

        # Applies Kea option-data entries to a Foreman options hash using OPTION_MAP.
        #
        # @param opts [Hash] The target options hash to populate.
        # @param option_data [Array<Hash>] The option-data array from Kea.
        # @return [void]
        def map_option_data(opts, option_data)
          option_data.each do |opt|
            mapping = OPTION_MAP[opt['name']]
            next unless mapping

            data = opt['data']
            opts[mapping[:key]] = mapping[:list] ? data&.split(',')&.map(&:strip) : data
          end
        end

        # Creates a Foreman Lease object from Kea data and adds it to the cache.
        #
        # @param lease [Hash] The lease data from Kea's lease4-get-all response.
        # @param staging [Staging] The buffer to populate with the parsed lease.
        # @return [void]
        def process_lease(lease, staging)
          ip = lease['ip-address']
          mac = lease['hw-address']
          subnet_obj = staging.service.find_subnet(ip)
          unless subnet_obj
            logger.warn "Skipping lease for IP #{ip} as it does not belong to any known subnet."
            return
          end

          record = ::Proxy::DHCP::Lease.new(nil, ip, mac, subnet_obj, lease['cltt'], lease['expire'], 'active')
          staging.service.add_lease(subnet_obj.network, record)
        end
      end
    end
  end
end
