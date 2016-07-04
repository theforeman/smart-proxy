module ::Proxy::DHCP
  module NativeMS
    class PluginConfiguration
      def load_classes
        require 'dhcpsapi'
        require 'dhcp_native_ms/dhcp_native_ms_main'
      end

      def load_dependency_injection_wirings(container_instance, settings)
        container_instance.dependency :dhcps_api, lambda { ::DhcpsApi::Server.new(settings[:server]) }
        container_instance.dependency :dhcp_provider,
                                      lambda { Proxy::DHCP::NativeMS::Provider.new(container_instance.get_dependency(:dhcps_api), settings[:subnets], settings[:disable_ddns]) }

      end
    end
  end
end
