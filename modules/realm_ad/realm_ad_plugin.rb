module Proxy::ADRealm
  class Plugin < Proxy::Provider
    load_classes ::Proxy::ADRealm::ConfigurationLoader
    load_depedency_injection_wirings ::Proxy::ADRealm::ConfigurationLoader

    validate_presence :keytab_path, :principal
    validate_readable :keytab_path

    plugin :realm_ad, ::Proxy::VERSION
  end
end