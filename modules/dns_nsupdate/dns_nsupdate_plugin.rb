module ::Proxy::Dns::Nsupdate
  class Plugin < ::Proxy::Provider
    plugin :dns_nsupdate, ::Proxy::VERSION

    default_settings :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    validate_readable :dns_key

    after_activation do
      require 'dns_nsupdate/dns_nsupdate_main'
      require 'dns_nsupdate/nsupdate_dependencies'
    end
  end
end
