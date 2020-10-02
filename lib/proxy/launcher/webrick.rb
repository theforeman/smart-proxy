require 'sd_notify'

module Launcher
  class Webrick
    include ::Proxy::Log

    attr_reader :launcher

    def initialize(launcher)
      @launcher = launcher
    end

    def launch
      http_app = build_http_app
      https_app = build_https_app
      install_webrick_callback!(http_app, https_app)

      t1 = Thread.new { webrick_server(https_app, settings.bind_host, settings.https_port).start } unless https_app.nil?
      t2 = Thread.new { webrick_server(http_app, settings.bind_host, settings.http_port).start } unless http_app.nil?

      Proxy::SignalHandler.install_traps

      (t1 || t2).join
    end

    private

    def settings
      launcher.settings
    end

    def webrick_server(app, addresses, port)
      server = ::WEBrick::HTTPServer.new(app)
      addresses.each { |a| server.listen(a, port) }
      server.mount "/", Rack::Handler::WEBrick, app[:app]
      server
    end

    def build_http_app
      return unless launcher.http_enabled?

      plugins = launcher.plugins.select { |p| p[:state] == :running && p[:http_enabled] }
      return unless plugins.any?

      app = Rack::Builder.new do
        plugins.each { |p| instance_eval(p[:class].http_rackup) }
      end

      {
        :app => app,
        :server => :webrick,
        :DoNotListen => true,
        :Port => settings.http_port, # only being used to correctly log http port being used
        :Logger => ::Proxy::LogBuffer::TraceDecorator.instance,
        :AccessLog => [],
        :ServerSoftware => "foreman-proxy/#{Proxy::VERSION}",
        :daemonize => false,
      }
    end

    def build_https_app
      unless launcher.https_enabled?
        logger.warn "Missing SSL setup, https is disabled."
        return
      end

      plugins = launcher.plugins.select { |p| p[:state] == :running && p[:https_enabled] }
      return unless plugins.any?

      app = Rack::Builder.new do
        plugins.each { |p| instance_eval(p[:class].https_rackup) }
      end

      ssl_options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      ssl_options |= OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE if defined?(OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE)
      # This is required to disable SSLv3 on Ruby 1.8.7
      ssl_options |= OpenSSL::SSL::OP_NO_SSLv2 if defined?(OpenSSL::SSL::OP_NO_SSLv2)
      ssl_options |= OpenSSL::SSL::OP_NO_SSLv3 if defined?(OpenSSL::SSL::OP_NO_SSLv3)
      ssl_options |= OpenSSL::SSL::OP_NO_TLSv1 if defined?(OpenSSL::SSL::OP_NO_TLSv1)
      ssl_options |= OpenSSL::SSL::OP_NO_TLSv1_1 if defined?(OpenSSL::SSL::OP_NO_TLSv1_1)

      settings.tls_disabled_versions&.each do |version|
        constant = OpenSSL::SSL.const_get("OP_NO_TLSv#{version.to_s.tr('.', '_')}") rescue nil

        if constant
          logger.info "TLSv#{version} will be disabled."
          ssl_options |= constant
        else
          logger.warn "TLSv#{version} was not found."
        end
      end

      {
        :app => app,
        :server => :webrick,
        :DoNotListen => true,
        :Port => settings.https_port, # only being used to correctly log https port being used
        :Logger => ::Proxy::LogBuffer::Decorator.instance,
        :ServerSoftware => "foreman-proxy/#{Proxy::VERSION}",
        :SSLEnable => true,
        :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER,
        :SSLPrivateKey => load_ssl_private_key(settings.ssl_private_key),
        :SSLCertificate => load_ssl_certificate(settings.ssl_certificate),
        :SSLCACertificateFile => settings.ssl_ca_file,
        :SSLOptions => ssl_options,
        :SSLCiphers => launcher.ciphers,
        :daemonize => false,
      }
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

    def install_webrick_callback!(*apps)
      apps.compact!

      # track how many webrick apps are still starting up
      @pending_webrick = apps.size
      @pending_webrick_lock = Mutex.new

      apps.each do |app|
        # add a callback to each server, decrementing the pending counter
        app[:StartCallback] = lambda do
          @pending_webrick_lock.synchronize do
            @pending_webrick -= 1
            launched(apps) if @pending_webrick.zero?
          end
        end
      end
    end

    def launched(apps)
      logger.info("Smart proxy has launched on #{apps.size} socket(s), waiting for requests")
      SdNotify.ready
    end
  end
end
