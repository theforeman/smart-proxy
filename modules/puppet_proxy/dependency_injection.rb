module Proxy::Puppet
  module DependencyInjection
    include Proxy::DependencyInjection::Accessors
    def container_instance
      @container_instance ||= ::Proxy::Plugins.instance.find { |p| p[:name] == :puppet }[:di_container]
    end
  end
end
