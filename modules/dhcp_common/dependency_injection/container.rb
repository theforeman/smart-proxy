module Proxy::DHCP
  module DependencyInjection
    class Container < Proxy::DependencyInjection::Container; end

    module Wiring
      include Proxy::DependencyInjection::Wiring

      def container_instance
        Container.instance
      end
    end

    module Injectors
      include Proxy::DependencyInjection::Accessors

      def container_instance
        Container.instance
      end
    end
  end
end
