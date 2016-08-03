module Proxy::Dns
  module DependencyInjection
    class Dependencies
      extend Proxy::Log
      extend Proxy::DependencyInjection::Wiring
      def self.container_instance
        logger.warn('Proxy::Dns::DependencyInjection::Dependencies class has been deprecated and will be removed in future versions.'\
          'Please use ::Proxy::Dns::YourPlugin#load_dependency_injection_wirings instead.')
        @container_instance ||= ::Proxy::Plugins.instance.find {|p| p[:name] == :dns }[:di_container]
      end
    end
  end
end
