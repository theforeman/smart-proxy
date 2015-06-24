module Proxy::DHCP
  module DependencyInjection
    class Dependencies
      extend Wiring

      dependency :memory_store, ::Proxy::MemoryStore
      dependency :subnet_service, ::Proxy::DHCP::SubnetService
    end
  end
end
