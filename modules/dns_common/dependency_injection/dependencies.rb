require 'dns_common/dependency_injection/container'

module Proxy::Dns
  module DependencyInjection
    class Dependencies
      extend Proxy::Dns::DependencyInjection::Wiring
    end
  end
end
