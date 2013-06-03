require "test/unit"
$: << File.join(File.dirname(__FILE__), '..', 'lib')

logdir = File.join(File.dirname(__FILE__), '..', 'logs')
FileUtils.mkdir_p(logdir) unless File.exists?(logdir)

require 'testing_proxy_settings'
require "proxy"
require "mocha/setup"
require "rack/test"
require 'sinatra'
