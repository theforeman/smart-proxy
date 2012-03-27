module Proxy::Puppet

  require 'proxy/puppet/puppet_class'
  require 'puppet'

  class Environment

    class << self
      # return a list of all puppet environments
      def all
        puppet_environments.map { |env, path| new(:name => env, :paths => path.split(":")) }
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
          env[:production] = conf[:main][:modulepath] || conf[:master][:modulepath]
        end

        # are we using dynamic puppet environments?
        env.each do|environment, modulepath|
          if modulepath and modulepath.include?("$environment")
            # expand $confdir if defined and used in modulepath
            if conf[:main][:confdir] and modulepath.include?("$confdir")
              modulepath.sub!("$confdir", conf[:main][:confdir])
            end
            # Dynamic environments - get every directory under the modulepath
            modulepath.gsub(/\$environment.*/,"/").split(":").each do |base_dir|
              Dir.glob("#{base_dir}/*") do |dir|
                e = dir.split("/").last
                env[e] = modulepath.gsub("$environment", e)
              end
            end
            # get rid of the main environment
            env.delete(environment)
          end
        end

        env.reject { |k, v| k.nil? or v.nil? }
      end
    end

    attr_reader :name, :paths

    def initialize args
      @name = args[:name].to_s  || raise("Must provide a name")
      @paths= args[:paths].to_s || raise("Must provide a path")
    end

    def to_s
      name
    end

    def classes
      paths.map {|path| PuppetClass.scan_directory path}.flatten
    end

  end
end
