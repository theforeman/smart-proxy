module ::Proxy::DHCP::NativeMS
  class PluginConfiguration
    def load_dependency_injection_wirings(container, settings)
      container.dependency :memory_store, ::Proxy::MemoryStore
      container.dependency :subnet_service, (lambda do
        ::Proxy::DHCP::SubnetService.new(container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store),
                                         container.get_dependency(:memory_store), container.get_dependency(:memory_store))
      end)
      container.dependency :dhcp_provider, (lambda do
        Proxy::DHCP::NativeMS::Provider.new(settings[:server], settings[:subnets], container.get_dependency(:subnet_service))
      end)
    end

    def load_classes
      require 'dhcp_common/subnet_service'
      require 'dhcp_common/server'
      require 'dhcp_native_ms/dhcp_native_ms_main'
    end
  end
end
