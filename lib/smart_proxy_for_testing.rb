require 'proxy'
require 'checks'
require 'proxy/log'
require 'proxy/settings'
require 'proxy/settings/plugin'
require 'proxy/settings/global'
require 'proxy/util'
require 'proxy/http_downloads'
require 'proxy/helpers'
require 'proxy/plugin'
require 'proxy/error'

require 'sinatra/base'
require 'sinatra/ssl_client_verification'
require 'sinatra/trusted_hosts'

Proxy::SETTINGS = ::Proxy::Settings::Global.new(:log_file => './logs/test.log', :log_level => 'DEBUG')
Proxy::VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).chomp

::Sinatra::Base.set :run, false

class ::Proxy::Plugin
  ::Sinatra::Base.register ::Sinatra::TrustedHosts

  def self.load_test_settings(a_hash)
    @settings = ::Proxy::Settings::Plugin.new(plugin_default_settings, a_hash)
  end
end
