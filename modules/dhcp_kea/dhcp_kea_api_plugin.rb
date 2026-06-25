# frozen_string_literal: true

require 'smart_proxy_dhcp_kea_api/dhcp_kea_api_version'
require 'smart_proxy_dhcp_kea_api/plugin_configuration'

module Proxy
  module DHCP
    module KeaApi
      # The main plugin class for the `dhcp_kea_api` provider. This class serves
      # as the entry point for the Foreman Smart Proxy to load and configure the
      # plugin. It defines the plugin's name, version, dependencies on other
      # modules, default settings, and hooks into the dependency injection framework.
      #
      # @see Proxy::DHCP::KeaApi::PluginConfiguration For how dependencies are loaded and wired.
      class Plugin < ::Proxy::Provider
        # Registers the provider with the Smart Proxy, giving it a unique name
        # (`:dhcp_kea_api`) and sourcing the version from the VERSION constant.
        plugin :dhcp_kea_api, ::Proxy::DHCP::KeaApi::VERSION

        # Declares a dependency on the core Smart Proxy DHCP module. This ensures
        # that the base classes we inherit from (like DHCP::Server) are available.
        requires :dhcp, '>= 1.17'

        # Defines the default settings for this provider. These values are used
        # if they are not overridden in the user's settings file
        # (`/etc/foreman-proxy/settings.d/dhcp_kea_api.yml`).
        # The `kea_api_username` and `kea_api_password` enable HTTP Basic
        # Authentication when the Kea control agent requires it.
        default_settings kea_api_url: 'http://127.0.0.1:8000/',
                         kea_api_username: nil,
                         kea_api_password: nil,
                         blacklist_duration_minutes: 5,
                         open_timeout: 5,
                         read_timeout: 10,
                         cache_ttl: 60

        # Hooks into the Smart Proxy's dependency injection (DI) framework. These lines
        # delegate the responsibility of loading the required classes and wiring up
        # their dependencies to the `PluginConfiguration` class. This keeps this
        # main plugin file clean and declarative.
        load_classes ::Proxy::DHCP::KeaApi::PluginConfiguration
        load_dependency_injection_wirings ::Proxy::DHCP::KeaApi::PluginConfiguration

        # Tells the Smart Proxy to start these specific services from our DI container
        # when the provider is enabled. `:subnet_service` manages the data cache,
        # and `:unused_ips` handles IP blacklist management.
        start_services :subnet_service, :unused_ips
      end
    end
  end
end
