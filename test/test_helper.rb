require "test/unit"
$: << File.join(File.dirname(__FILE__), '..', 'lib')
$: << File.join(File.dirname(__FILE__), '..', 'modules')

logdir = File.join(File.dirname(__FILE__), '..', 'logs')
FileUtils.mkdir_p(logdir) unless File.exists?(logdir)

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


require "mocha/setup"
require "rack/test"

Proxy::SETTINGS = Proxy::Settings.load_global_settings(File.expand_path("fixtures/test_settings.yml", File.dirname(__FILE__)))
Proxy::VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).chomp

class ::Proxy::Plugin
  def self.load_test_settings(a_hash)
    @settings = ::Proxy::Settings::Plugin.new(plugin_default_settings, a_hash)
  end
end
