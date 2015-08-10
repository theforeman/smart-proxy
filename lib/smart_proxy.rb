APP_ROOT = "#{File.dirname(__FILE__)}/.."

require 'proxy'

require 'fileutils'
require 'pathname'
require 'checks'
require 'webrick/https'
require 'daemon' # FIXME: Do we still need this?

require 'checks'
require 'proxy/log'
require 'proxy/settings'
require 'proxy/settings/plugin'
require 'proxy/settings/global'
require 'proxy/util'
require 'proxy/http_download'
require 'proxy/helpers'
require 'proxy/pluggable'
require 'proxy/plugin'
require 'proxy/provider_factory'
require 'proxy/provider'
require 'proxy/error'
require 'proxy/request'

require 'bundler_helper'
Proxy::BundlerHelper.require_groups(:default)

require 'rack-patch' if Rack.release < "1.3"
require 'sinatra-patch'
require 'sinatra/authorization'
require 'poodles-fix'

module Proxy
  SETTINGS = Settings.load_global_settings
  VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).chomp

  ::Sinatra::Base.set :run, false
  ::Sinatra::Base.set :root, APP_ROOT
  ::Sinatra::Base.set :views, APP_ROOT + '/views'
  ::Sinatra::Base.set :public_folder, APP_ROOT + '/public'
  ::Sinatra::Base.set :logging, false # we are not going to use Rack::Logger
  ::Sinatra::Base.use ::Proxy::LoggerMiddleware # instead, we have our own logging middleware
  ::Sinatra::Base.use ::Rack::CommonLogger, ::Proxy::Log.logger
  ::Sinatra::Base.set :env, :production
  ::Sinatra::Base.register ::Sinatra::Authorization

  require 'root/root'
  require 'facts/facts'
  require 'dns/dns'
  require 'dns_nsupdate/dns_nsupdate'
  require 'dns_nsupdate/dns_nsupdate_gss'
  require 'dns_dnscmd/dns_dnscmd'
  require 'dns_virsh/dns_virsh'
  require 'templates/templates'
  require 'tftp/tftp'
  require 'dhcp/dhcp'
  require 'puppetca/puppetca'
  require 'puppet_proxy/puppet'
  require 'bmc/bmc'
  require "realm/realm"

  def self.version
    {:version => VERSION}
  end

  class Launcher
    include ::Proxy::Log

    def pid_path
      SETTINGS.daemon_pid
    end

    def create_pid_dir
      if SETTINGS.daemon
        FileUtils.mkdir_p(File.dirname(pid_path)) unless File.exist?(pid_path)
      end
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
        :daemonize => false,
        :pid => (SETTINGS.daemon && !https_enabled?) ? pid_path : nil)
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
          :SSLEnable => true,
          :SSLVerifyClient => OpenSSL::SSL::VERIFY_PEER,
          :SSLPrivateKey => load_ssl_private_key(SETTINGS.ssl_private_key),
          :SSLCertificate => load_ssl_certificate(SETTINGS.ssl_certificate),
          :SSLCACertificateFile => SETTINGS.ssl_ca_file,
          :daemonize => false,
          :pid => SETTINGS.daemon ? pid_path : nil)
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

    def launch
      ::Proxy::Plugins.configure_loaded_plugins

      create_pid_dir
      http_app = http_app()
      https_app = https_app()
      raise Exception.new("Both http and https are disabled, unable to start.") if http_app.nil? && https_app.nil?

      Process.daemon if SETTINGS.daemon

      t1 = Thread.new { https_app.start } unless https_app.nil?
      t2 = Thread.new { http_app.start } unless http_app.nil?

      sleep 5 # Rack installs its own trap; Sleeping for 5 secs insures we overwrite it with our own
      trap(:INT) do
        exit(0)
      end

      (t1 || t2).join
    rescue SignalException => e
      # This is to prevent the exception handler below from catching SignalException exceptions.
      logger.info("Caught #{e}. Exiting")
      raise
    rescue SystemExit
      # do nothing. This is to prevent the exception handler below from catching SystemExit exceptions.
      raise
    rescue Exception => e
      logger.error("Error during startup, terminating. #{e}")
      logger.debug("#{e}:#{e.backtrace.join("\n")}")

      puts "Errors detected on startup, see log for details. Exiting."
      exit(1)
    end
  end
end
