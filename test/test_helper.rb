require "test/unit"
$: << File.join(File.dirname(__FILE__), '..', 'lib')
require "proxy"
require "proxy/puppetca"
require "proxy/tftp"
require "mocha/setup"
require "rack/test"
require 'sinatra'
