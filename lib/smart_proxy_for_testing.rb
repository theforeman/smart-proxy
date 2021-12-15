require 'smart_proxy'
require 'json'
require 'rack'
require 'sinatra'
require 'webrick/https'
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
require 'launcher'

require 'sinatra/base'
require 'sinatra/authorization'

Proxy::SETTINGS = ::Proxy::Settings::Global.new(:log_file => './logs/test.log', :log_level => 'DEBUG')
Proxy::VERSION = File.read(File.join(__dir__, '..', 'VERSION')).chomp

::Sinatra::Base.set :run, false
::Sinatra::Base.register ::Sinatra::Authorization

module ::Proxy::Pluggable
  def load_test_settings(a_hash = {})
    @settings = ::Proxy::Settings::Plugin.new(plugin_default_settings, a_hash)
  end
end
