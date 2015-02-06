module ::Proxy::Dns::Nsupdate
  class Plugin < ::Proxy::Provider
    plugin :dns_nsupdate, ::Proxy::VERSION,
           :factory => proc { |attrs| ::Proxy::Dns::Nsupdate::Record.record(attrs) }

    default_settings :dns_server => 'localhost', :dns_key => nil

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_nsupdate/dns_nsupdate_main'
    end
  end
end
