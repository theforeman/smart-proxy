module Proxy::Puppet

  require 'proxy/puppet/puppet_class'
  require 'puppet'

  class Environment

    class << self
      # return a list of all puppet environments
      def all
        puppet_environments.map { |env, path| new(:name => env, :path => path) }
      end

      def find name
        all.each { |e| return e if e.name == name }
        nil
      end

      private

      def puppet_environments
        Puppet.clear
        Puppet[:config] = SETTINGS.puppet_conf if SETTINGS.puppet_conf
        Puppet.parse_config
        conf = Puppet.settings.instance_variable_get(:@values)

        env = { }
        # query for the environments variable
        unless conf[:main][:environments].nil?
          conf[:main][:environments].split(",").each { |e| env[e.to_sym] = conf[e.to_sym][:modulepath] unless conf[e.to_sym][:modulepath].nil? }
        else
          # 0.25 doesn't require the environments variable anymore, scanning for modulepath
          conf.keys.each { |p| env[p] = conf[p][:modulepath] unless conf[p][:modulepath].nil? }
          # puppetmaster section "might" also returns the modulepath
          env.delete :main
          env.delete :puppetmasterd if env.size > 1

        end
        if env.values.compact.size == 0
          # fall back to defaults - we probably don't use environments
          env[:production] = conf[:main][:modulepath] || conf[:master][:modulepath]
        end
        env.reject { |k, v| k.nil? or v.nil? }
      end
    end

    attr_reader :name, :path

    def initialize args
      @name = args[:name].to_s || raise("Must provide a name")
      @path = args[:path].to_s || raise("Must provide a path")
    end

    def to_s
      name
    end

    def classes
      PuppetClass.scan_directory path
    end

  end
end