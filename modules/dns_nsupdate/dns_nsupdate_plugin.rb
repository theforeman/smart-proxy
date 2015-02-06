module ::Proxy::Dns::Nsupdate
  class Plugin < ::Proxy::Provider
    plugin :dns_nsupdate, ::Proxy::VERSION,
           :main_module => :dns, :factory => proc { |attrs| ::Proxy::Dns::Nsupdate::Record.record(attrs) }

    default_settings :enabled => true, :dns_server => 'localhost', :dns_ttl => 86_400,
                     :dns_key => nil

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_nsupdate/dns_nsupdate_main'
    end
  end
end
