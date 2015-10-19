module Proxy::Dns
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    uses_provider
    default_settings :use_provider => 'dns_nsupdate', :dns_ttl => 86_400
    plugin :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_common/dependency_injection/container'
      require 'dns_common/dependency_injection/dependencies'
    end
  end
end
