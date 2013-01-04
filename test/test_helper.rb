require "test/unit"
$: << File.join(File.dirname(__FILE__), '..', 'lib')

require "proxy/settings"

# Override settings to enable subsystems we intend to test
[ "tftp", "puppet", "puppetca", "bmc" ].each { |s| SETTINGS.send("#{s}=", true) }
logdir = File.join(File.dirname(__FILE__), '..', 'logs')
FileUtils.mkdir_p(logdir) unless File.exists?(logdir)
SETTINGS.log_file = File.join(logdir, 'test.log')
SETTINGS.puppet_conf = File.join(File.dirname(__FILE__), 'fixtures', 'puppet.conf')

require "proxy"
require "mocha/setup"
require "rack/test"
require 'sinatra'
