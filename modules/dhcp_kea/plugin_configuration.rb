# frozen_string_literal: true

module Proxy
  module DHCP
    module KeaApi
      # This class manages the setup and configuration of the KeaApi plugin's
      # internal components. It follows a pattern used by the Foreman Smart Proxy's
      # dependency injection (DI) framework. Its responsibilities are divided into
      # two main parts: loading the necessary classes into memory and then "wiring"
      # them together by defining how each service gets created and what its
      # dependencies are.
      class PluginConfiguration
        # Loads all the necessary classes for this provider into memory.
        # This is called by the Smart Proxy before the dependency injection
        # wirings are configured.

        def load_classes
          require 'dhcp_common/free_ips'
          require 'smart_proxy_dhcp_kea_api/kea_api_client'
          require 'smart_proxy_dhcp_kea_api/dhcp_kea_api_subnet_service'
          require 'smart_proxy_dhcp_kea_api/dhcp_kea_api_main'
        end

        # Configures the dependency injection wirings for the KeaApi provider.
        # The container is responsible for creating and managing instances of our services.
        #
        # @param container [Proxy::DependencyInjection::Container] The DI container to register services with.
        # @param settings [Hash] The settings hash for this provider.

        def load_dependency_injection_wirings(container, settings)
          # A singleton service that manages the temporary blacklisting of suggested IP addresses
          # to prevent race conditions. Its duration is configured via the settings file.
          container.singleton_dependency :unused_ips, -> { ::Proxy::DHCP::FreeIps.new(settings[:blacklist_duration_minutes]) }

          # The custom client for communicating with the Kea API. This is registered as a singleton
          # so that a single client instance (with its configuration) is shared across all requests.
          # @see Proxy::DHCP::KeaApi::Client#initialize
          container.singleton_dependency :kea_client, (lambda do
            ::Proxy::DHCP::KeaApi::Client.new(
              url: settings[:kea_api_url],
              username: settings[:kea_api_username],
              password: settings[:kea_api_password],
              open_timeout: settings[:open_timeout],
              read_timeout: settings[:read_timeout]
            )
          end)

          # The custom service for caching all subnet, reservation, and lease data.
          # This is a singleton because we want one central, authoritative cache that all
          # requests can share. Each store must be a separate instance to avoid collisions
          # between leases and reservations keyed by the same IP/MAC.
          # @see Proxy::DHCP::KeaApi::SubnetService#initialize
          container.singleton_dependency :subnet_service, (lambda do
            ::Proxy::DHCP::KeaApi::SubnetService.new(
              container.get_dependency(:kea_client),
              ::Proxy::MemoryStore.new,
              ::Proxy::MemoryStore.new,
              ::Proxy::MemoryStore.new,
              ::Proxy::MemoryStore.new,
              ::Proxy::MemoryStore.new,
              cache_ttl: settings[:cache_ttl],
              managed_subnets: settings.fetch(:managed_subnets, nil)
            )
          end)

          # The main provider class that ties everything together. This is the entry point
          # for handling DHCP requests from Foreman. It depends on the subnet service,
          # the API client, and the IP blacklist service to do its job.
          # @see Proxy::DHCP::KeaApi::Provider#initialize
          container.singleton_dependency :dhcp_provider, (lambda do
            ::Proxy::DHCP::KeaApi::Provider.new(
              container.get_dependency(:subnet_service),
              container.get_dependency(:kea_client),
              container.get_dependency(:unused_ips)
            )
          end)
        end
      end
    end
  end
end
