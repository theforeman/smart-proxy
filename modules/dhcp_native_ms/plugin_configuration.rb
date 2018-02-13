module ::Proxy::DHCP
  module NativeMS
    class PluginConfiguration
      def load_classes
        require 'dhcpsapi'
        require 'dhcp_common/free_ips'
        require 'dhcp_native_ms/dhcp_native_ms_main'
      end

      def load_dependency_injection_wirings(container_instance, settings)
        container_instance.dependency :dhcps_api, lambda { ::DhcpsApi::Server.new(settings[:server]) }
        container_instance.singleton_dependency :free_ips, lambda {::Proxy::DHCP::FreeIps.new(settings[:blacklist_duration_minutes]) }
        container_instance.dependency :dhcp_provider, (lambda do
          Proxy::DHCP::NativeMS::Provider.new(container_instance.get_dependency(:dhcps_api),
                                              settings[:subnets], settings[:disable_ddns], container_instance.get_dependency(:free_ips))
        end)

      end
    end
  end
end
