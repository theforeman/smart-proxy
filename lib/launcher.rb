require 'openssl'
require 'proxy/log'

begin
  require 'rackup/handler/webrick'
  WEBRICK_HANDLER = Rackup::Handler::WEBrick
rescue LoadError
  require 'rack'
  WEBRICK_HANDLER = Rack::Handler::WEBrick
end
require 'proxy/settings'
require 'proxy/signal_handler'
require 'proxy/log_buffer/trace_decorator'
require 'sd_notify'

CRYPTO_POLICIES_CONFIG = '/etc/crypto-policies/back-ends/opensslcnf.config'.freeze
TLS_MIN_VERSION_MAP = {
  '1.0' => OpenSSL::SSL::TLS1_VERSION,
  '1.1' => OpenSSL::SSL::TLS1_1_VERSION,
  '1.2' => OpenSSL::SSL::TLS1_2_VERSION,
  '1.3' => OpenSSL::SSL::TLS1_3_VERSION,
}.freeze

module Proxy
  class Launcher
    include ::Proxy::Log

    attr_reader :settings

    def initialize(settings = SETTINGS)
      @settings = settings
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

      http_settings = {
        :app => app,
        :Port => http_port, # only being used to correctly log http port being used
        :Logger => ::Proxy::LogBuffer::TraceDecorator.instance,
      }
      base_app_settings.merge(http_settings)
    end

    def https_app(https_port, plugins = https_plugins)
      unless https_enabled?
        logger.warn "Missing SSL setup, https is disabled."
        return nil
      end

      unless File.readable?(settings.ssl_ca_file)
        logger.error "Unable to read #{settings.ssl_ca_file}. Are the values correct in settings.yml and do permissions allow reading?"
      end

      app = Rack::Builder.new do
        plugins.each { |p| instance_eval(p.https_rackup) }
      end

      tls_ciphers = resolve_tls_ciphers
      cipher_list, ciphersuites = validate_tls_ciphers!(tls_ciphers)

      https_settings = {
        :app => app,
        :Port => https_port, # only being used to correctly log https port being used
        :Logger => ::Proxy::LogBuffer::Decorator.instance,
        :SSLEnable => true,
        :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER,
        :SSLPrivateKey => load_ssl_private_key(settings.ssl_private_key),
        :SSLCertificate => load_ssl_certificate(settings.ssl_certificate),
        :SSLCACertificateFile => settings.ssl_ca_file,
        :SSLOptions => build_ssl_options,
        :SSLCiphers => cipher_list,
        :SSLCiphersuites => ciphersuites,
        :SSLMinVersion => resolve_tls_min_version,
      }
      base_app_settings.merge(https_settings)
    end

    def build_ssl_options
      ssl_options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      ssl_options |= OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE
      # Disable client initiated renegotiation
      ssl_options |= OpenSSL::SSL::OP_NO_RENEGOTIATION

      ssl_options
    end

    def resolve_tls_min_version
      return nil unless settings.tls_min_version

      min_version = settings.tls_min_version.to_s
      unless TLS_MIN_VERSION_MAP.key?(min_version)
        raise "Invalid tls_min_version '#{min_version}'. Valid values: #{TLS_MIN_VERSION_MAP.keys.join(', ')}"
      end

      logger.info "Setting minimum TLS version to #{min_version}."
      TLS_MIN_VERSION_MAP[min_version]
    end

    def resolve_tls_ciphers
      configured = settings.tls_ciphers
      raise "Invalid tls_ciphers value '#{configured}': must be a String" if !configured.nil? && !configured.is_a?(String)
      return nil if configured == ''
      return configured unless configured.nil?

      unless File.exist?(CRYPTO_POLICIES_CONFIG)
        logger.debug "No crypto-policies detected, using HIGH cipher string as default."
        return 'HIGH'
      end

      if cipher_string_supported?('PROFILE=SYSTEM')
        logger.info "Crypto-policies detected, using PROFILE=SYSTEM for TLS ciphers."
        return 'PROFILE=SYSTEM'
      end

      cipher_string = crypto_policies_cipher_string
      if cipher_string && cipher_string_supported?(cipher_string)
        logger.info "Crypto-policies detected, but this OpenSSL build does not support the " \
                    "'PROFILE=SYSTEM' cipher-list alias. Using the CipherString resolved from " \
                    "#{CRYPTO_POLICIES_CONFIG} directly instead."
        return cipher_string
      end

      logger.warn "Crypto-policies detected but could not be applied on this Ruby/OpenSSL build; " \
                  "falling back to the 'HIGH' cipher string."
      'HIGH'
    end

    # Extracted so resolve_tls_ciphers can probe candidate cipher strings before
    # committing to them, instead of only discovering they're unusable at startup.
    def cipher_string_supported?(ciphers)
      OpenSSL::SSL::SSLContext.new.ciphers = ciphers
      true
    rescue OpenSSL::SSL::SSLError
      false
    end

    def crypto_policies_cipher_string
      File.foreach(CRYPTO_POLICIES_CONFIG) do |line|
        return Regexp.last_match(1).strip if line =~ /^CipherString\s*=\s*(.+)$/
      end
      nil
    rescue SystemCallError => e
      logger.warn "Unable to read #{CRYPTO_POLICIES_CONFIG}: #{e.message}"
      nil
    end

    def validate_tls_ciphers!(ciphers)
      return [nil, nil] if ciphers.nil?

      if ciphers == 'PROFILE=SYSTEM' && !settings.tls_min_version.nil? && settings.tls_min_version != ''
        logger.warn "tls_min_version is configured together with tls_ciphers 'PROFILE=SYSTEM'. " \
                    "The system crypto policy minimum TLS version may be overridden by this setting."
      end

      cipher_list = cipher_string_supported?(ciphers) ? ciphers : nil

      if OpenSSL::SSL::SSLContext.method_defined?(:ciphersuites=)
        ciphersuites = begin
          OpenSSL::SSL::SSLContext.new.ciphersuites = ciphers
          ciphers
        rescue OpenSSL::SSL::SSLError
          nil
        end
      elsif settings.tls_ciphers
        logger.warn "tls_ciphers is configured but this Ruby/OpenSSL build does not support " \
                    "OpenSSL::SSL::SSLContext#ciphersuites=. TLS 1.3 connections will not be " \
                    "restricted by tls_ciphers."
      end

      # If the cipher list and ciphersuites are not valid, return the original string to let the SSL server fail at startup
      return [ciphers, nil] unless cipher_list || ciphersuites

      if cipher_list.nil? && ciphersuites && settings.tls_min_version != '1.3'
        logger.warn "tls_ciphers '#{ciphers}' is only valid for TLS 1.3. " \
                    "Set tls_min_version to '1.3' to prevent TLS 1.2 and lower connections with unrestricted ciphers."
      end

      if settings.tls_ciphers && settings.tls_min_version == '1.3' && ciphersuites.nil?
        raise "tls_ciphers '#{ciphers}' is not valid for TLS 1.3 but tls_min_version is 1.3."
      end

      [cipher_list, ciphersuites]
    end

    def load_ssl_private_key(path)
      OpenSSL::PKey.read(File.read(path))
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

    def webrick_server(app, addresses, port)
      server = ::WEBrick::HTTPServer.new(app)
      begin
        addresses.each { |a| server.listen(a, port) }
      rescue ::OpenSSL::SSL::SSLError => e
        raise "Invalid tls_ciphers value '#{app[:SSLCiphers]}': #{e.message}"
      end
      server.mount "/", WEBRICK_HANDLER, app[:app]

      # WEBrick 1.9.x does not support :SSLMinVersion in its config hash, so we
      # apply min_version= directly on the SSL context after WEBrick creates it.
      # This patch should be removed once WEBrick adds support for :SSLMinVersion.
      #
      # :SSLCiphers is passed to SSL_CTX_set_cipher_list(), covering TLS 1.0–1.2.
      # :SSLCiphersuites is applied here via SSL_CTX_set_ciphersuites() for TLS 1.3.
      if app[:SSLEnable]
        server.ssl_context.min_version = app[:SSLMinVersion] if app[:SSLMinVersion]
        server.ssl_context.ciphersuites = app[:SSLCiphersuites] if app[:SSLCiphersuites]
      end

      server
    end

    def launch
      raise Exception.new("Both http and https are disabled, unable to start.") unless http_enabled? || https_enabled?

      ::Proxy::PluginInitializer.new(::Proxy::Plugins.instance).initialize_plugins

      http_app = http_app(settings.http_port)
      https_app = https_app(settings.https_port)
      install_webrick_callback!(http_app, https_app)

      t1 = Thread.new { webrick_server(https_app, settings.bind_host, settings.https_port).start } unless https_app.nil?
      t2 = Thread.new { webrick_server(http_app, settings.bind_host, settings.http_port).start } unless http_app.nil?

      Proxy::SignalHandler.install_traps

      (t1 || t2).join
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

    def base_app_settings
      {
        :server => :webrick,
        :DoNotListen => true,
        :ServerSoftware => "foreman-proxy/#{Proxy::VERSION}",
        :daemonize => false,
        :AccessLog => [],
      }
    end
  end
end
