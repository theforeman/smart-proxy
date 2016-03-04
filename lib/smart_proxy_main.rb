APP_ROOT = "#{File.dirname(__FILE__)}/.."

require 'smart_proxy'
require 'launcher'

require 'fileutils'
require 'pathname'
require 'checks'
require 'webrick/https'
require 'daemon'

require 'checks'
require 'proxy/log'
require 'proxy/settings'
require 'proxy/settings/plugin'
require 'proxy/settings/global'
require 'proxy/dependency_injection'
require 'proxy/util'
require 'proxy/http_download'
require 'proxy/helpers'
require 'proxy/memory_store'
require 'proxy/pluggable'
require 'proxy/plugin'
require 'proxy/plugin_initializer'
require 'proxy/plugin_validators'
require 'proxy/provider_factory'
require 'proxy/provider'
require 'proxy/error'
require 'proxy/request'

require 'bundler_helper'
Proxy::BundlerHelper.require_groups(:default)

require 'json'
require 'rack'
require 'rack-patch' if Rack.release < "1.3"
require 'sinatra'
require 'sinatra-patch'
require 'sinatra/authorization'
require 'webrick-patch'

module Proxy
  SETTINGS = Settings.load_global_settings
  VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).chomp

  ::Sinatra::Base.set :run, false
  ::Sinatra::Base.set :root, APP_ROOT
  ::Sinatra::Base.set :logging, false # we are not going to use Rack::Logger
  ::Sinatra::Base.use ::Proxy::LoggerMiddleware # instead, we have our own logging middleware
  ::Sinatra::Base.use ::Rack::CommonLogger, ::Proxy::LogBuffer::Decorator.instance
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
  require 'puppet_proxy/puppet'
  require 'bmc/bmc'
  require 'realm/realm'
  require 'logs/logs'

  def self.version
    {:version => VERSION}
  end
end
