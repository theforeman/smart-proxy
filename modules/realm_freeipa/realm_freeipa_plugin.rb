module Proxy::FreeIPARealm
  class Plugin < Proxy::Provider
    default_settings :ipa_config => '/etc/ipa/default.conf', :remove_dns => true

    load_classes ::Proxy::FreeIPARealm::ConfigurationLoader
    load_dependency_injection_wirings ::Proxy::FreeIPARealm::ConfigurationLoader

    validate_presence :keytab_path, :principal
    validate_readable :keytab_path, :ipa_config

    plugin :realm_freeipa, ::Proxy::VERSION
  end
end
