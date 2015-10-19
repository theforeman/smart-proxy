require 'dns_common/dependency_injection/dependencies'

class Proxy::Dns::DependencyInjection::Dependencies
  dependency :dns_provider, Proxy::Dns::Nsupdate::Record
end
