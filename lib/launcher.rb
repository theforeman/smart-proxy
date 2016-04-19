require 'proxy/log'
require 'proxy/settings'
require 'proxy/signal_handler'

module Proxy
  class Launcher
    include ::Proxy::Log

    def pid_path
      SETTINGS.daemon_pid
    end

    def http_enabled?
      !SETTINGS.http_port.nil?
    end

    def https_enabled?
      SETTINGS.ssl_private_key && SETTINGS.ssl_certificate && SETTINGS.ssl_ca_file
    end

    def http_app
      return nil unless http_enabled?
      app = Rack::Builder.new do
        ::Proxy::Plugins.instance.select {|p| p[:state] == :running && p[:http_enabled]}.each do |p|
          instance_eval(p[:class].http_rackup)
        end
      end

      {
        :app => app,
        :server => :webrick,
        :BindAddress => SETTINGS.bind_host,
        :Port => SETTINGS.http_port,
        :Logger => ::Proxy::LogBuffer::Decorator.instance,
        :daemonize => false
      }
    end

    def https_app
      unless https_enabled?
        logger.warn "Missing SSL setup, https is disabled."
        return nil
      end

      app = Rack::Builder.new do
        ::Proxy::Plugins.instance.select {|p| p[:state] == :running && p[:https_enabled]}.each do |p|
          instance_eval(p[:class].https_rackup)
        end
      end

      ssl_options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      ssl_options |= OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE if defined?(OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE)
      # This is required to disable SSLv3 on Ruby 1.8.7
      ssl_options |= OpenSSL::SSL::OP_NO_SSLv2 if defined?(OpenSSL::SSL::OP_NO_SSLv2)
      ssl_options |= OpenSSL::SSL::OP_NO_SSLv3 if defined?(OpenSSL::SSL::OP_NO_SSLv3)
      ssl_options |= OpenSSL::SSL::OP_NO_TLSv1 if !SETTINGS.enable_tls_v1 && defined?(OpenSSL::SSL::OP_NO_TLSv1)

      {
        :app => app,
        :server => :webrick,
        :BindAddress => SETTINGS.bind_host,
        :Port => SETTINGS.https_port,
        :Logger => ::Proxy::LogBuffer::Decorator.instance,
        :SSLEnable => true,
        :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER,
        :SSLPrivateKey => load_ssl_private_key(SETTINGS.ssl_private_key),
        :SSLCertificate => load_ssl_certificate(SETTINGS.ssl_certificate),
        :SSLCACertificateFile => SETTINGS.ssl_ca_file,
        :SSLOptions => ssl_options,
        :daemonize => false
      }
    end

    def load_ssl_private_key(path)
      OpenSSL::PKey::RSA.new(File.read(path))
    rescue Exception => e
      logger.error "Unable to load private SSL key. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
      raise e
    end

    def load_ssl_certificate(path)
      OpenSSL::X509::Certificate.new(File.read(path))
    rescue Exception => e
      logger.error "Unable to load SSL certificate. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
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
      File.open(pid_path, ::File::CREAT | ::File::EXCL | ::File::WRONLY){|f| f.write(Process.pid.to_s) }
      at_exit { File.delete(pid_path) if File.exist?(pid_path) }
    rescue Errno::EEXIST
      check_pid
      retry
    end

    def webrick_server(app)
      server = ::WEBrick::HTTPServer.new(app)
      server.mount "/", Rack::Handler::WEBrick, app[:app]
      server
    end

    def launch
      raise Exception.new("Both http and https are disabled, unable to start.") unless http_enabled? || https_enabled?

      if SETTINGS.daemon
        check_pid
        Process.daemon
        write_pid
      end

      ::Proxy::PluginInitializer.new(::Proxy::Plugins.instance).initialize_plugins

      http_app = http_app()
      https_app = https_app()

      t1 = Thread.new { webrick_server(https_app).start } unless https_app.nil?
      t2 = Thread.new { webrick_server(http_app).start } unless http_app.nil?

      Proxy::SignalHandler.install_traps

      (t1 || t2).join
    rescue SignalException => e
      logger.debug("Caught #{e}. Exiting")
      raise
    rescue SystemExit
      # do nothing. This is to prevent the exception handler below from catching SystemExit exceptions.
      raise
    rescue Exception => e
      logger.error("Error during startup, terminating. #{e}", e.backtrace)
      puts "Errors detected on startup, see log for details. Exiting: #{e}"
      exit(1)
    end
  end
end
