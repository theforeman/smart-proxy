module Proxy::Puppet
  class Plugin < Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :puppet_provider => 'puppetrun', :puppetdir => '/etc/puppet', :use_cache => true,
                     :salt_puppetrun_cmd => 'puppet.run'
    plugin :puppet, ::Proxy::VERSION
  end
end
