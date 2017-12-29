module Proxy::AdRealm
  class Plugin < Proxy::Provider
    default_settings :computername_prefix => '', :computername_prefix => false, :computername_use_fqdn => false

    load_classes ::Proxy::AdRealm::ConfigurationLoader
    load_dependency_injection_wirings ::Proxy::AdRealm::ConfigurationLoader

    validate_presence :realm, :keytab_path, :principal, :domain_controller
    validate_readable :keytab_path

    plugin :realm_ad, ::Proxy::VERSION
  end
end
