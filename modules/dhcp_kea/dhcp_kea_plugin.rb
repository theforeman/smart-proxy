module Proxy::DHCP::Kea
  class Plugin < ::Proxy::Provider
    plugin :dhcp_kea, ::Proxy::VERSION

    capability 'dhcp_filename_ipv4'
    capability 'dhcp_filename_hostname'

    default_settings :dhcp_kea_url => 'http://127.0.0.1:8000/',
                     :dhcp_kea_verify_ssl => true,
                     :dhcp_kea_http_timeout => 5,
                     :blacklist_duration_minutes => 30 * 60

    requires :dhcp, ::Proxy::VERSION

    load_classes do
      require 'dhcp_common/dhcp_common'
      require 'dhcp_common/server'
      require 'dhcp_common/free_ips'
      require 'dhcp_kea/kea_api_client'
      require 'dhcp_kea/dhcp_kea_main'
    end

    load_dependency_injection_wirings do |container_instance, settings|
      container_instance.singleton_dependency :kea_api_client, (lambda do
        ::Proxy::DHCP::Kea::KeaApiClient.new(
          settings[:dhcp_kea_url],
          settings[:dhcp_kea_username],
          settings[:dhcp_kea_password],
          verify_ssl: settings[:dhcp_kea_verify_ssl],
          timeout: settings[:dhcp_kea_http_timeout]
        )
      end)

      container_instance.singleton_dependency :free_ips, -> { ::Proxy::DHCP::FreeIps.new(settings[:blacklist_duration_minutes]) }

      container_instance.dependency :dhcp_provider, (lambda do
        ::Proxy::DHCP::Kea::Provider.new(
          container_instance.get_dependency(:kea_api_client),
          settings[:subnets],
          container_instance.get_dependency(:free_ips)
        )
      end)
    end
  end
end
