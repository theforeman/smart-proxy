require "checks"
require "yaml"
require "ostruct"
require "pathname"

require 'proxy/dns/default_dns_settings'
require 'proxy/puppet/default_puppet_settings'

class Settings < OpenStruct
  DEFAULTS = [Proxy::DNS::DefaultSettings::DEFAULTS, Proxy::Puppet::DefaultSettings::DEFAULTS].inject({}) do |all, current|
    all.merge!(current)
  end

  def self.load_from_file(settings_path = Pathname.new(__FILE__).join("..", "..","..","config","settings.yml"))
    settings = YAML.load(File.read(settings_path))
    if PLATFORM =~ /mingw/
      settings.delete :puppetca if settings.has_key? :puppetca
      settings.delete :puppet   if settings.has_key? :puppet
      settings[:x86_64] = File.exist?('c:\windows\sysnative\cmd.exe')
    end
    load(settings)
  end

  def self.load(ahash)
    Settings.new(DEFAULTS.merge(ahash))
  end

  def method_missing(symbol, *args)
    nil
  end
end
