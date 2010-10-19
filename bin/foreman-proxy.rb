#!/usr/bin/env ruby

$LOAD_PATH.unshift *Dir["#{File.dirname(__FILE__)}/../lib"]

require "rubygems"
require "sinatra"
require "proxy"
require "json"
require "haml"
require "tftp_api" if SETTINGS.tftp
require "puppet_api" if SETTINGS.puppet
require "puppetca_api" if SETTINGS.puppetca
require "dns_api" if SETTINGS.dns
require "dhcp_api" if SETTINGS.dhcp
