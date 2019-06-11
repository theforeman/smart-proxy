require 'proxy/settings_from_env'
require 'ostruct'

module ::Proxy::Settings
  class Global < ::OpenStruct
    DEFAULT_SETTINGS = {
      :settings_directory => Pathname.new(__FILE__).join("..","..","..","..","config","settings.d").expand_path.to_s,
      :https_port => 8443,
      :log_file => "/var/log/foreman-proxy/proxy.log",
      :file_rolling_keep => 6,
      :file_rolling_size => 100,
      :file_rolling_age => 'weekly',
      :file_logging_pattern => '%d %.8X{request} [%.1l] %m',
      :system_logging_pattern => '%m',
      :log_level => "INFO",
      :daemon => false,
      :daemon_pid => "/var/run/foreman-proxy/foreman-proxy.pid",
      :forward_verify => true,
      :bind_host => ["*"],
      :log_buffer => 2000,
      :log_buffer_errors => 1000,
      :ssl_disabled_ciphers => [],
      :tls_disabled_versions => []
    }

    HOW_TO_NORMALIZE = {
      :foreman_url => lambda { |value| value.end_with?("/") ? value : value + "/" },
      :bind_host => lambda { |value| value.is_a?(Array) ? value : [value] }
    }

    attr_reader :used_defaults

    def initialize(settings)
      if RUBY_PLATFORM =~ /mingw/
        settings.delete :puppetca if settings.has_key? :puppetca
        settings.delete :puppet   if settings.has_key? :puppet
        settings[:x86_64] = File.exist?('c:\windows\sysnative\cmd.exe')
      end

      @used_defaults = DEFAULT_SETTINGS.keys - settings.keys

      default_and_user_settings = DEFAULT_SETTINGS.merge(settings)
      settings_to_use = Hash[ default_and_user_settings.map do |key, value|
        [key, normalize_setting(key, value, HOW_TO_NORMALIZE)]
      end ]

      super(settings_to_use)
    end

    def normalize_setting(key, value, how_to)
      return value unless how_to.has_key?(key)
      how_to[key].call(value)
    end

    def apply_argv(args)
      self.daemon = true if args.include?('--daemonize')
      self.daemon = false if args.include?('--no-daemonize')
    end

    def apply_env(env)
      DEFAULT_SETTINGS.each do |setting_key, setting_value|
        env_key = "FOREMAN_PROXY_#{setting_key.to_s.upcase}"
        next unless env.key?(env_key)
        value = env[env_key]
        setting_type = Proxy::SettingsFromEnv.guess_setting_type(setting_value)
        casted_value = Proxy::SettingsFromEnv.cast_value(setting_type, value)
        normalized_value = normalize_setting(setting_key, casted_value, HOW_TO_NORMALIZE)
        self[setting_key] = normalized_value
      end
    end
  end
end
