require 'dhcp_common/dependency_injection/dependencies'

class Proxy::DHCP::DependencyInjection::Dependencies
  dependency :dhcp_provider, Proxy::DHCP::Virsh::Provider
end
