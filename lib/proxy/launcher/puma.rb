require 'puma'
require 'puma/configuration'
require 'proxy/app'

module Launcher
  class Puma
    attr_reader :launcher

    def initialize(launcher)
      @launcher = launcher
    end

    def launch
      ::Puma::Launcher.new(conf).run
    end

    private

    def conf
      ::Puma::Configuration.new do |user_config|
        user_config.environment('production')
        user_config.app(app)

        if launcher.http_enabled?
          bind_hosts do |host|
            user_config.bind "tcp://#{host}:#{settings.http_port}"
          end
        end

        if launcher.https_enabled?
          ssl_options = {
            key: settings.ssl_private_key,
            cert: settings.ssl_certificate,
            ca: settings.ssl_ca_file,
            ssl_cipher_filter: launcher.ciphers.join(':'),
            verify_mode: 'peer',
            no_tlsv1: true,
            no_tlsv1_1: true,
          }

          bind_hosts do |host|
            user_config.ssl_bind(host, settings.https_port, ssl_options)
          end
        end

        user_config.on_restart do
          ::Proxy::LogBuffer::Decorator.instance.roll_log = true
        end

        begin
          user_config.plugin('systemd')
        rescue ::Puma::UnknownPlugin
        end
      end
    end

    def app
      ::Proxy::App.new(launcher.plugins)
    end

    def binds
    end

    def bind_hosts
      settings.bind_host.each do |host|
        if host == '*'
          yield ipv6_enabled? ? '[::]' : '0.0.0.0'
        else
          begin
            addr = IPAddr.new(host)
            yield addr.ipv6? ? "[#{addr}]" : addr.to_s
          rescue IPAddr::InvalidAddressError
            yield host
          end
        end
      end
    end

    def settings
      launcher.settings
    end

    def ipv6_enabled?
      File.exist?('/proc/net/if_inet6') || (RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/)
    end
  end
end
