module ::Proxy::PuppetCa::TokenWhitelisting
  class Plugin < ::Proxy::Provider
    plugin :puppetca_token_whitelisting, ::Proxy::VERSION

    requires :puppetca, ::Proxy::VERSION
    default_settings :sign_all => false, :tokens_file => '/var/lib/foreman-proxy/tokens.yml', :token_ttl => 360

    load_classes ::Proxy::PuppetCa::TokenWhitelisting::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetCa::TokenWhitelisting::PluginConfiguration
  end
end
