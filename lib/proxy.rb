module Proxy
  MODULES = %w{dns dhcp tftp puppetca puppet}
  require "proxy/settings"
  require "rubygems"
  require "fileutils"
  require "pathname"
  require "proxy/log"
  require "proxy/util"
  require "proxy/tftp"     if SETTINGS.tftp
  require "proxy/puppetca" if SETTINGS.puppet_ca
  require "proxy/puppet"   if SETTINGS.puppet
  require "proxy/dns"      if SETTINGS.dns
  require "proxy/dhcp"     if SETTINGS.dhcp

  def self.features
    MODULES.collect{|mod| mod if SETTINGS.send mod}.compact
  end

end
