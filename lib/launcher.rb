require 'proxy/log'
require 'proxy/settings'
require 'proxy/signal_handler'

module Proxy
  class Launcher
    include ::Proxy::Log

    def pid_path
      SETTINGS.daemon_pid
    end

    def https_enabled?
      SETTINGS.ssl_private_key && SETTINGS.ssl_certificate && SETTINGS.ssl_ca_file
    end

    def http_app
      return nil if SETTINGS.http_port.nil?
      app = Rack::Builder.new do
        ::Proxy::Plugins.enabled_plugins.each do |p|
          instance_eval(p.http_rackup)
        end
      end

      Rack::Server.new(
        :app => app,
        :server => :webrick,
        :Host => SETTINGS.bind_host,
        :Port => SETTINGS.http_port,
        :Logger => ::Proxy::Log.logger,
        :daemonize => false)
    end

    def https_app
      unless https_enabled?
        logger.warn "Missing SSL setup, https is disabled."
        nil
      else
        app = Rack::Builder.new do
          ::Proxy::Plugins.enabled_plugins.each {|p| instance_eval(p.https_rackup)}
        end

        Rack::Server.new(
          :app => app,
          :server => :webrick,
          :Host => SETTINGS.bind_host,
          :Port => SETTINGS.https_port,
          :Logger => ::Proxy::Log.logger,
          :SSLEnable => true,
          :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER,
          :SSLPrivateKey => load_ssl_private_key(SETTINGS.ssl_private_key),
          :SSLCertificate => load_ssl_certificate(SETTINGS.ssl_certificate),
          :SSLCACertificateFile => SETTINGS.ssl_ca_file,
          :daemonize => false)
      end
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
      File.open(pid_path, ::File::CREAT | ::File::EXCL | ::File::WRONLY){|f| f.write("#{Process.pid}") }
      at_exit { File.delete(pid_path) if File.exist?(pid_path) }
    rescue Errno::EEXIST
      check_pid
      retry
    end

    def launch
      ::Proxy::Plugins.configure_loaded_plugins

      http_app = http_app()
      https_app = https_app()
      raise Exception.new("Both http and https are disabled, unable to start.") if http_app.nil? && https_app.nil?

      if SETTINGS.daemon
        check_pid
        Process.daemon
        write_pid
      end

      t1 = Thread.new { https_app.start } unless https_app.nil?
      t2 = Thread.new { http_app.start } unless http_app.nil?

      Proxy::SignalHandler.install_traps

      (t1 || t2).join
    rescue SignalException => e
      logger.info("Caught #{e}. Exiting")
      raise
    rescue SystemExit
      # do nothing. This is to prevent the exception handler below from catching SystemExit exceptions.
      raise
    rescue Exception => e
      logger.error("Error during startup, terminating. #{e}")
      logger.debug("#{e}:#{e.backtrace.join("\n")}")

      puts "Errors detected on startup, see log for details. Exiting: #{e}"
      exit(1)
    end
  end
end
