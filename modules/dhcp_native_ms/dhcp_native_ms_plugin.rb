module ::Proxy::DHCP::NativeMS
  class Plugin < ::Proxy::Provider
    plugin :dhcp_native_ms, ::Proxy::VERSION

    requires :dhcp, ::Proxy::VERSION

    after_activation do
      require 'dhcp_native_ms/dhcp_native_ms_main'
      require 'dhcp_native_ms/dependencies'
    end
  end
end
