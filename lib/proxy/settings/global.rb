module ::Proxy::Settings
  class Global < ::OpenStruct
    DEFAULT_SETTINGS = {
      :settings_directory => Pathname.new(__dir__).join("..", "..", "..", "config", "settings.d").expand_path.to_s,
      :https_port => 8443,
      :log_file => "/var/log/foreman-proxy/proxy.log",
      :file_rolling_keep => 6,
      :file_rolling_size => 0,
      :file_rolling_age => 'weekly',
      :file_logging_pattern => '%d %.8X{request} [%.1l] %m',
      :system_logging_pattern => '%m',
      :log_level => "INFO",
      :forward_verify => true,
      :bind_host => ["*"],
      :log_buffer => 2000,
      :log_buffer_errors => 1000,
      :ssl_disabled_ciphers => [],
      :tls_disabled_versions => [],
      :dns_resolv_timeouts => [5, 8, 13], # Ruby default is [5, 20, 40] which is a bit too much for us
    }

    HOW_TO_NORMALIZE = {
      :foreman_url => ->(value) { value.end_with?("/") ? value : value + "/" },
      :bind_host => ->(value) { value.is_a?(Array) ? value : [value] },
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
  end
end
