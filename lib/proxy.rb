module Proxy
  MODULES = %w{dns dhcp tftp puppetca puppet}
  VERSION = "0.3.1"

  require "checks"
  require "proxy/settings"
  require "fileutils"
  require "pathname"
  require "rubygems" if USE_GEMS # required for testing
  require "proxy/log"
  require "proxy/util"
  require "proxy/tftp"     if SETTINGS.tftp
  require "proxy/puppetca" if SETTINGS.puppetca
  require "proxy/puppet"   if SETTINGS.puppet
  require "proxy/dns"      if SETTINGS.dns
  require "proxy/dhcp"     if SETTINGS.dhcp

  def self.features
    MODULES.collect{|mod| mod if SETTINGS.send mod}.compact
  end

  def self.version
    {:version => VERSION}
  end

end
