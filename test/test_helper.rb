require "test/unit"
$: << File.join(File.dirname(__FILE__), '..', 'lib')
require "proxy"
require "mocha"
require "rack/test"
require 'sinatra'
