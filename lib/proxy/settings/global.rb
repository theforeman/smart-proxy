module ::Proxy::Settings
  class Global < ::OpenStruct
    DEFAULT_SETTINGS = {
      :settings_directory => Pathname.new(__FILE__).join("..","..","..","..","config","settings.d").expand_path.to_s,
      :https_port => 8443,
      :log_file => "/var/log/foreman-proxy/proxy.log",
      :log_level => "ERROR",
      :daemon => false,
      :daemon_pid => "/var/run/foreman-proxy/foreman-proxy.pid",
      :forward_verify => true,
      :bind_host => "*"
    }

    attr_reader :used_defaults

    def initialize(settings)
      if ::PLATFORM =~ /mingw/
        settings.delete :puppetca if settings.has_key? :puppetca
        settings.delete :puppet   if settings.has_key? :puppet
        settings[:x86_64] = File.exist?('c:\windows\sysnative\cmd.exe')
      end
      @used_defaults = DEFAULT_SETTINGS.keys - settings.keys
      super(DEFAULT_SETTINGS.merge(settings))
    end
  end
end
