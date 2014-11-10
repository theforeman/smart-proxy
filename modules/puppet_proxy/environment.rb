require 'puppet'
require 'puppet_proxy/initializer'
require 'puppet_proxy/config_reader'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/api_request'
require 'proxy/util'

class Proxy::Puppet::Environment
  extend Proxy::Log

  class << self
    include Proxy::Util

    # return a list of all puppet environments
    def all
      Proxy::Puppet::Initializer.load
      conf = Proxy::Puppet::ConfigReader.new(Proxy::Puppet::Initializer.config).get

      if use_environment_api?(conf)
        api_environments.map { |env, path| new(:name => env, :paths => path) }
      else
        config_environments(conf).map { |env, path| new(:name => env, :paths => path.split(":")) }
      end
    end

    def find name
      all.find { |e| e.name == name }
    end

    private

    def use_environment_api?(conf)
      force = to_bool(Proxy::Puppet::Plugin.settings.puppet_use_environment_api, nil)
      return force unless force.nil?
      !!([:main, :master].find { |s| (conf[s] && conf[s][:environmentpath] && !conf[s][:environmentpath].empty?) })
    end

    def api_environments
      response = Proxy::Puppet::EnvironmentsApi.new.find_environments
      raise Proxy::Puppet::DataError.new("No environments list in Puppet API response") unless response['environments']
      response['environments'].inject({}) do |envs, item|
        envs[item.first] = item.last['settings']['modulepath'] if item.last && item.last['settings'] && item.last['settings']['modulepath']
        envs
      end
    end

    def config_environments(conf)
      env = { }
      # query for the environments variable
      if conf[:main][:environments].nil?
        # 0.25 and newer doesn't require the environments variable anymore, scanning for modulepath
        conf.keys.each { |p| env[p] = conf[p][:modulepath] unless conf[p][:modulepath].nil? }
        # puppetmaster section "might" also returns the modulepath
        env.delete :main
        env.delete :puppetmasterd if env.size > 1
      else
        conf[:main][:environments].split(",").each { |e| env[e.to_sym] = conf[e.to_sym][:modulepath] unless conf[e.to_sym][:modulepath].nil? }
      end
      if env.values.compact.size == 0
        # fall back to defaults - we probably don't use environments
        env[:production] = conf[:main][:modulepath] || conf[:master][:modulepath] || '/etc/puppet/modules'
        logger.warn "No environments found - falling back to defaults (production - #{env[:production]})"
      end
      if env.size == 1 && env.keys.first == :master && !env.values.first.include?('$environment')
        # If we only have an entry in [master] it should really be called production
        logger.warn "Re-writing single 'master' environment as 'production'"
        env[:production] = env[:master]
        env.delete :master
      end

      new_env = env.clone
      # are we using dynamic puppet environments?
      env.each do|environment, modulepath|
        next unless modulepath

        # expand $confdir if defined and used in modulepath
        if modulepath.include?("$confdir")
          if conf[:main][:confdir]
            modulepath.gsub!("$confdir", conf[:main][:confdir])
          else
            # /etc/puppet is the default if $confdir is not defined
            modulepath.gsub!("$confdir", "/etc/puppet")
          end
        end

        # parting modulepath into static and dynamic paths
        staticpath = modulepath.split(":")
        dynamicpath = modulepath.split(":")

        modulepath.split(":").each do |base_dir|
          if base_dir.include?("$environment")
            # remove this entry from the static paths
            staticpath.delete base_dir
          else
            # remove this entry from the dynamic paths
            dynamicpath.delete base_dir
          end
        end

        # remove or add static environment
        if staticpath.empty?
          new_env.delete environment
        else
          new_env[environment] = staticpath.join(':')
        end

        # create dynamic environments and modulepaths (array of hash)
        unless dynamicpath.empty?
          temp_environment = []

          dynamicpath.each do |base_dir|
            # Dynamic environments - get every directory under the modulepath
            Dir.glob("#{base_dir.gsub(/\$environment(.*)/,"/")}/*").grep(/\/[A-Za-z0-9_]+$/) do |dir|
              e = dir.split("/").last
              temp_environment.push(e => base_dir.gsub("$environment", e))
            end
          end

          # group array of hashes, join values (modulepaths) and create dynamic environment => modulepath
          dynamic_environment = temp_environment.group_by(&:keys).map{|k, v| {k.first => v.flatten.map(&:values).join(':')}}

          dynamic_environment.each do |h|
            h.each do |k,v|
              new_env[k.to_sym] = v
            end
          end
        end
      end

      new_env.reject { |k, v| k.nil? || v.nil? }
    end
  end

  attr_reader :name, :paths

  def initialize args
    @name = args[:name].to_s || raise("Must provide a name")
    @paths= args[:paths]     || raise("Must provide a path")
  end

  def to_s
    name
  end

  def classes
    ::Proxy::Puppet::Initializer.load
    conf = ::Proxy::Puppet::ConfigReader.new(::Proxy::Puppet::Initializer.config).get
    eparser = (conf[:main] && conf[:main][:parser] == 'future') || (conf[:master] && conf[:master][:parser] == 'future')

    paths.map {|path| ::Proxy::Puppet::PuppetClass.scan_directory path, name, eparser}.flatten
  end
end