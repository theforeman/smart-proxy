module Proxy::PuppetCa
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :ssldir => '/var/lib/puppet/ssl', :puppetdir => '/etc/puppet'
    plugin :puppetca, ::Proxy::VERSION
  end
end