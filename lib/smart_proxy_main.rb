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
require 'poodles-fix'

module Proxy
  SETTINGS = Settings.load_global_settings
  VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).chomp

  ::Sinatra::Base.set :run, false
  ::Sinatra::Base.set :root, APP_ROOT
  ::Sinatra::Base.set :views, APP_ROOT + '/views'
  ::Sinatra::Base.set :public_folder, APP_ROOT + '/public'
  ::Sinatra::Base.set :logging, false # we are not going to use Rack::Logger
  ::Sinatra::Base.use ::Proxy::LoggerMiddleware # instead, we have our own logging middleware
  ::Sinatra::Base.use ::Rack::CommonLogger, ::Proxy::Log.logger
  ::Sinatra::Base.set :env, :production
  ::Sinatra::Base.register ::Sinatra::Authorization

  require 'root/root'
  require 'facts/facts'
  require 'dns/dns'
  require 'dns_nsupdate/dns_nsupdate'
  require 'dns_nsupdate/dns_nsupdate_gss'
  require 'dns_dnscmd/dns_dnscmd'
  require 'dns_virsh/dns_virsh'
  require 'templates/templates'
  require 'tftp/tftp'
  require 'dhcp/dhcp'
  require 'puppetca/puppetca'
  require 'puppet_proxy/puppet'
  require 'bmc/bmc'
  require "realm/realm"

  def self.version
    {:version => VERSION}
  end
end
