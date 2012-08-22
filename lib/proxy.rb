module Proxy
  MODULES = %w{dhcp dns puppetca puppet squid tftp}
  VERSION = "1.0"

  require "checks"
  require "proxy/settings"
  require "fileutils"
  require "pathname"
  require "rubygems" if USE_GEMS # required for testing
  require "proxy/log"
  require "proxy/util"
  require "proxy/dhcp"     if SETTINGS.dhcp
  require "proxy/dns"      if SETTINGS.dns
  require "proxy/puppetca" if SETTINGS.puppetca
  require "proxy/puppet"   if SETTINGS.puppet
  require "proxy/squid"    if SETTINGS.squid
  require "proxy/tftp"     if SETTINGS.tftp

  def self.features
    MODULES.collect{|mod| mod if SETTINGS.send mod}.compact
  end

  def self.version
    {:version => VERSION}
  end

end
