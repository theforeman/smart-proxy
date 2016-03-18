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

      ::Thin::Logging.logger = ::Proxy::LogBuffer::Decorator.instance
      ::Thin::Server.new(SETTINGS.bind_host, SETTINGS.http_port, :signals => false) do
        ::Proxy::Plugins.enabled_plugins.each {|p| instance_eval(p.http_rackup)}
      end
    end

    def https_app
      if !https_enabled?
        logger.warn "Missing SSL setup, https is disabled."
        return nil
      end

      ::Thin::Logging.logger = ::Proxy::LogBuffer::Decorator.instance
      s = ::Thin::Server.new(SETTINGS.bind_host, SETTINGS.https_port, :signals => false) do
        ::Proxy::Plugins.enabled_plugins.each {|p| instance_eval(p.https_rackup)}
      end

      ssl_version = ['TLSv1_2']
      ssl_version << 'TLSv1_1' unless defined?(OpenSSL::SSL::OP_NO_TLSv1_1)
      ssl_version << 'TLSv1' unless defined?(OpenSSL::SSL::OP_NO_TLSv1)
      ciphers = <<-EOL
ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-CBC-SHA:ECDHE-RSA-AES256-CBC-SHA:
AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA
EOL
      s.ssl = true

      s.ssl_options = {:private_key_file => SETTINGS.ssl_private_key,
                       :cert_chain_file => SETTINGS.ssl_certificate,
                       :verify_peer => true,
                       :cipher_list => ciphers.gsub("\n", ""),
                       :ssl_version => ssl_version}
      s
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

    def configure_plugins
      ::Proxy::Plugins.update(::Proxy::PluginInitializer.new.initialize_plugins(::Proxy::Plugins.loaded))
    end

    def launch
      configure_plugins

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
      logger.error("Error during startup, terminating. #{e}", e.backtrace)
      puts "Errors detected on startup, see log for details. Exiting: #{e}"
      exit(1)
    end
  end
end
