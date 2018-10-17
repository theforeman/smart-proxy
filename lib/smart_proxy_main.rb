APP_ROOT = "#{File.dirname(__FILE__)}/.."

require 'smart_proxy'
require 'launcher'

require 'fileutils'
require 'pathname'
require 'checks'
require 'webrick/https'
require 'daemon'

require 'proxy/log'
require 'proxy/settings'
require 'proxy/settings/plugin'
require 'proxy/settings/global'
require 'proxy/dependency_injection'
require 'proxy/util'
require 'proxy/http_download'
require 'proxy/helpers'
require 'proxy/memory_store'
require 'proxy/plugin_validators'
require 'proxy/pluggable'
require 'proxy/plugins'
require 'proxy/plugin'
require 'proxy/plugin_initializer'
require 'proxy/provider_factory'
require 'proxy/provider'
require 'proxy/error'
require 'proxy/request'
require 'proxy/request_id_middleware'

require 'bundler_helper'
Proxy::BundlerHelper.require_groups(:default)

require 'json'
require 'rack'
require 'rack-patch' if Rack.release < "1.3"
require 'sinatra'
require 'sinatra/authorization'
require 'sinatra/default_not_found_page'
require 'webrick-patch'

module Proxy
  SETTINGS = Settings.initialize_global_settings
  VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).chomp

  ::Sinatra::Base.set :run, false
  ::Sinatra::Base.set :root, APP_ROOT
  ::Sinatra::Base.set :logging, false
  ::Sinatra::Base.use ::Proxy::RequestIdMiddleware
  ::Sinatra::Base.use ::Proxy::LoggerMiddleware
  ::Sinatra::Base.set :env, :production
  ::Sinatra::Base.register ::Sinatra::Authorization

  require 'root/root'
  require 'facts/facts'
  require 'dns/dns'
  require 'dns_nsupdate/dns_nsupdate'
  require 'dns_nsupdate/dns_nsupdate_gss'
  require 'dns_dnscmd/dns_dnscmd'
  require 'dns_libvirt/dns_libvirt'
  require 'templates/templates'
  require 'tftp/tftp'
  require 'dhcp/dhcp'
  require 'dhcp_isc/dhcp_isc'
  require 'dhcp_native_ms/dhcp_native_ms'
  require 'dhcp_libvirt/dhcp_libvirt'
  require 'puppetca/puppetca'
  require 'puppetca_http_api/puppetca_http_api'
  require 'puppetca_puppet_cert/puppetca_puppet_cert'
  require 'puppetca_hostname_whitelisting/puppetca_hostname_whitelisting'
  require 'puppetca_token_whitelisting/puppetca_token_whitelisting'
  require 'puppet_proxy/puppet'
  require 'puppet_proxy_customrun/puppet_proxy_customrun'
  require 'puppet_proxy_legacy/puppet_proxy_legacy'
  require 'puppet_proxy_mcollective/puppet_proxy_mcollective'
  require 'puppet_proxy_puppet_api/puppet_proxy_puppet_api'
  require 'puppet_proxy_puppetrun/puppet_proxy_puppetrun'
  require 'puppet_proxy_salt/puppet_proxy_salt'
  require 'puppet_proxy_ssh/puppet_proxy_ssh'
  require 'bmc/bmc'
  require 'realm/realm'
  require 'realm_freeipa/realm_freeipa'
  require 'logs/logs'
  require 'httpboot/httpboot'

  def self.version
    {:version => VERSION}
  end
end
