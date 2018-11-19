require 'proxy/log'
require 'proxy/util'
require 'proxy/sd_notify_all'
require 'proxy/settings'
require 'proxy/signal_handler'
require 'proxy/log_buffer/trace_decorator'
require 'sd_notify'
require 'rack'
require 'webrick'

module Proxy
  class Launcher
    include ::Proxy::Log
    include ::Proxy::Util

    attr_reader :settings

    def initialize(settings = Proxy::SETTINGS)
      @settings = settings
      if @settings.http_server_type == "puma"
        require 'puma'
        require 'rack/handler/puma'
        require 'puma-patch'
      end
      @servers = []
    end

    def pid_path
      settings.daemon_pid
    end

    def http_enabled?
      !settings.http_port.nil?
    end

    def https_enabled?
      settings.ssl_private_key && settings.ssl_certificate && settings.ssl_ca_file
    end

    def plugins
      ::Proxy::Plugins.instance.select { |p| p[:state] == :running }
    end

    def http_plugins
      plugins.select { |p| p[:http_enabled] }.map { |p| p[:class] }
    end

    def https_plugins
      plugins.select { |p| p[:https_enabled] }.map { |p| p[:class] }
    end

    def http_app(http_port, plugins = http_plugins)
      return nil unless http_enabled?
      app = Rack::Builder.new do
        plugins.each { |p| instance_eval(p.http_rackup) }
      end

      {
        :app => app,
        :server => settings.http_server_type.to_sym,
        :DoNotListen => true,
        :Port => http_port, # only being used to correctly log http port being used
        :Logger => ::Proxy::LogBuffer::TraceDecorator.instance,
        :AccessLog => [],
        :ServerSoftware => "foreman-proxy/#{Proxy::VERSION}",
        :daemonize => false,
      }
    end

    def https_app(https_port, plugins = https_plugins)
      unless https_enabled?
        logger.warn "Missing SSL setup, https is disabled."
        return nil
      end

      app = Rack::Builder.new do
        plugins.each { |p| instance_eval(p.https_rackup) }
      end

      ssl_enabled_ciphers = if settings.ssl_enabled_ciphers.is_a?(String)
                              settings.ssl_enabled_ciphers.split(':')
                            else
                              settings.ssl_enabled_ciphers
                            end

      app_details = {
        :app => app,
        :server => settings.http_server_type,
        :DoNotListen => true,
        :Port => https_port, # only being used to correctly log https port being used
        :Logger => ::Proxy::LogBuffer::Decorator.instance,
        :ServerSoftware => "foreman-proxy/#{Proxy::VERSION}",
        :SSLCiphers => ssl_enabled_ciphers,
        :daemonize => false,
      }

      case settings.http_server_type
      when "webrick"
        ssl_options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
        ssl_options |= OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE if defined?(OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE)
        ssl_options |= OpenSSL::SSL::OP_NO_SSLv2 if defined?(OpenSSL::SSL::OP_NO_SSLv2)
        ssl_options |= OpenSSL::SSL::OP_NO_SSLv3 if defined?(OpenSSL::SSL::OP_NO_SSLv3)
        ssl_options |= OpenSSL::SSL::OP_NO_TLSv1 if defined?(OpenSSL::SSL::OP_NO_TLSv1)
        ssl_options |= OpenSSL::SSL::OP_NO_TLSv1_1 if defined?(OpenSSL::SSL::OP_NO_TLSv1_1)

        if settings.tls_disabled_versions
          settings.tls_disabled_versions&.each do |version|
            constant = OpenSSL::SSL.const_get("OP_NO_TLSv#{version.to_s.tr('.', '_')}") rescue nil

            if constant
              logger.info "TLSv#{version} will be disabled."
              ssl_options |= constant
            else
              logger.warn "TLSv#{version} was not found."
            end
          end
        end

        app_details[:SSLEnable] = true
        app_details[:SSLVerifyClient] = OpenSSL::SSL::VERIFY_PEER
        app_details[:SSLCACertificateFile] = settings.ssl_ca_file
        app_details[:SSLPrivateKey] = load_ssl_private_key(settings.ssl_private_key)
        app_details[:SSLCertificate] = load_ssl_certificate(settings.ssl_certificate)
        app_details[:SSLOptions] = ssl_options
      when "puma"
        # https://github.com/puma/puma#binding-tcp--sockets
        app_details[:SSLArgs] = {
          :ca => settings.ssl_ca_file,
          :key => settings.ssl_private_key,
          :cert => settings.ssl_certificate,
          :verify_mode => 'peer',
        }
        app_details[:SSLArgs][:no_tlsv1] = "true"
        app_details[:SSLArgs][:no_tlsv1_1] = "true"
        # no additional TLS versions via tls_disabled_versions can be currently disabled for puma
        if settings.ssl_enabled_ciphers
          app_details[:SSLArgs][:ssl_cipher_list] = ssl_enabled_ciphers.join(':')
        end
      else
        raise "Unknown http_server_type: #{settings.http_server_type}"
      end
      app_details
    end

    def load_ssl_private_key(path)
      OpenSSL::PKey::RSA.new(File.read(path))
    rescue Exception => e
      logger.error "Unable to load private SSL key. Are the values correct in settings.yml and do permissions allow reading?", e
      raise e
    end

    def load_ssl_certificate(path)
      OpenSSL::X509::Certificate.new(File.read(path))
    rescue Exception => e
      logger.error "Unable to load SSL certificate. Are the values correct in settings.yml and do permissions allow reading?", e
      raise e
    end

    def pid_status
      return :exited unless File.exist?(pid_path)
      pid = ::File.read(pid_path).to_i
      return :dead if pid == 0
      Process.kill(0, pid)
      :running
    rescue Errno::ESRCH
      :dead
    rescue Errno::EPERM
      :not_owned
    end

    def check_pid
      case pid_status
      when :running, :not_owned
        logger.error "A server is already running. Check #{pid_path}"
        exit(2)
      when :dead
        File.delete(pid_path)
      end
    end

    def write_pid
      FileUtils.mkdir_p(File.dirname(pid_path)) unless File.exist?(pid_path)
      File.open(pid_path, ::File::CREAT | ::File::EXCL | ::File::WRONLY) { |f| f.write(Process.pid.to_s) }
      at_exit { File.delete(pid_path) if File.exist?(pid_path) }
    rescue Errno::EEXIST
      check_pid
      retry
    end

    def add_puma_server_callback(sd_notify)
      events = ::Puma::Events.new(::Proxy::LogBuffer::Decorator.instance, ::Proxy::LogBuffer::Decorator.instance)
      events.register(:state) do |status|
        if status == :running
          sd_notify.ready_all { sd_notify.status("Started all #{sd_notify.total} threads, ready", logger) }
          sd_notify.status("Started, #{sd_notify.pending} threads to go", logger) if sd_notify.pending > 0
        end
      end
      events
    end

    def format_ip_for_url(address)
      addr = IPAddr.new(address)
      addr.ipv6? ? "[#{addr}]" : addr.to_s
    rescue IPAddr::InvalidAddressError
      address
    end

    def add_puma_server(app, address, port, conn_type, sd_notify)
      address = format_ip_for_url(address)
      logger.debug "Launching Puma listener at #{address} port #{port}"
      if conn_type == :ssl
        host = "ssl://#{address}:#{port}/?#{hash_to_query_string(app[:SSLArgs])}"
      else
        host = address
      end
      logger.debug "Host URL: #{host}"
      # the following lines are from lib/rack/handler/puma.rb#run
      options = {Verbose: true, Port: port, Host: host}
      conf = Rack::Handler::Puma.config(app[:app], options)
      # install callback to notify systemd
      events = add_puma_server_callback(sd_notify)
      launcher = ::Puma::Launcher.new(conf, :events => events)
      @servers << launcher
      launcher.run
    end

    def add_webrick_server_callback(app, sd_notify)
      app[:StartCallback] = lambda do
        sd_notify.ready_all { sd_notify.status("Started all #{sd_notify.total} threads, ready", logger) }
        sd_notify.status("Started, #{sd_notify.pending} threads to go", logger) if sd_notify.pending > 0
      end
    end

    def add_webrick_server(app, addresses, port, sd_notify)
      # install callback to notify systemd
      add_webrick_server_callback(app, sd_notify)
      # initialize the server
      server = ::WEBrick::HTTPServer.new(app)
      addresses.each do |address|
        logger.debug "Launching Webrick listener at #{address} port #{port}"
        server.listen(address, port)
      end
      server.mount '/', Rack::Handler::WEBrick, app[:app]
      server
    end

    def ipv6_enabled?
      File.exist?('/proc/net/if_inet6') || (RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/)
    end

    def add_threaded_server(server_name, conn_type, app, addresses, port, sd_notify)
      result = []
      case server_name
      when "webrick"
        result << Thread.new do
          @servers << add_webrick_server(app, addresses, port, sd_notify).start
        end
      when "puma"
        addresses.flatten.each do |address|
          # Puma listens both on IPv4 and IPv6 on '::', there is no way to make Puma
          # to listen only on IPv6.
          address = '::' if address == '*' && ipv6_enabled?
          result << Thread.new do
            add_puma_server(app, address, port, conn_type, sd_notify)
          end
        end
      end
      result
    end

    def launch
      raise Exception.new("Both http and https are disabled, unable to start.") unless http_enabled? || https_enabled?

      if settings.daemon
        check_pid
        Process.daemon
        write_pid
      end

      ::Proxy::PluginInitializer.new(::Proxy::Plugins.instance).initialize_plugins

      http_app = http_app(settings.http_port)
      https_app = https_app(settings.https_port)
      hosts = settings.bind_host.is_a?(Array) ? settings.bind_host.size : 1
      expected = [http_app, https_app].compact.size * hosts
      logger.debug "Expected number of instances to launch: #{expected}"
      sd_notify = Proxy::SdNotifyAll.new(expected)
      sd_notify.status("Starting #{expected} threads", logger)

      http_server_name = settings.http_server_type
      https_server_name = settings.http_server_type
      threads = []
      if https_app
        threads += add_threaded_server(https_server_name,
                                       :ssl,
                                       https_app,
                                       settings.bind_host,
                                       settings.https_port,
                                       sd_notify)
      end

      if http_app
        threads += add_threaded_server(http_server_name,
                                       :tcp,
                                       http_app,
                                       settings.bind_host,
                                       settings.http_port,
                                       sd_notify)
      end

      Proxy::SignalHandler.install_traps(@servers)
      threads.each(&:join)
    rescue SignalException => e
      logger.debug("Caught #{e}. Exiting")
      raise
    rescue SystemExit
      # do nothing. This is to prevent the exception handler below from catching SystemExit exceptions.
      raise
    rescue Exception => e
      logger.error "Error during startup, terminating", e
      puts "Errors detected on startup, see log for details. Exiting: #{e}"
      exit(1)
    end
  end
end
