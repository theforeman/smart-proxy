APP_ROOT = "#{File.dirname(__FILE__)}/.."

require "checks"
require "rubygems" if USE_GEMS
require "proxy"
require "sinatra-patch"
require "json"
require "proxy/log"
require "helpers"

class SmartProxy < Sinatra::Base
  attr_reader :ssl_options

  include Proxy::Log
  require 'helpers'

  set :root, APP_ROOT
  set :views, APP_ROOT + '/views'
  set :logging, true
  set :env,     :production
  set :run,     true

  # This changed in later Sinatra versions
  if ( Sinatra::VERSION.split('.').map{|s|s.to_i} <=> [1,3,0] ) > 0
    set :public_folder, APP_ROOT + '/public'
  else
    set :public, APP_ROOT + '/public'
  end

  require "tftp_api"     if SETTINGS.tftp
  require "puppet_api"   if SETTINGS.puppet
  require "puppetca_api" if SETTINGS.puppetca
  require "dns_api"      if SETTINGS.dns
  require "dhcp_api"     if SETTINGS.dhcp
  require "bmc_api"      if SETTINGS.bmc
  require "realm_api"    if SETTINGS.realm
  require "features_api"

  begin
    require "facter"
    require "facts_api"
  rescue LoadError
    warn "Facter was not found, Facts API disabled"
  end

  # we force webrick to allow SSL
  set :server, "webrick"
  set :port, SETTINGS.port if SETTINGS.port

  # SSL Setup
  unless SETTINGS.ssl_private_key and SETTINGS.ssl_certificate and SETTINGS.ssl_ca_file
    warn "WARNING: Missing SSL setup, working in clear text mode !\n"
    @ssl_options = {}
  else
    begin
      @ssl_options = {:SSLEnable => true,
        :SSLVerifyClient      => OpenSSL::SSL::VERIFY_PEER,
        :SSLPrivateKey        => OpenSSL::PKey::RSA.new(File.read(SETTINGS.ssl_private_key)),
        :SSLCertificate       => OpenSSL::X509::Certificate.new(File.read(SETTINGS.ssl_certificate)),
        :SSLCACertificateFile => SETTINGS.ssl_ca_file
      }
    rescue => e
      warn "Unable to access the SSL keys. Are the values correct in settings.yml and do permissions allow reading?: #{e}"
      exit 1
    end
  end

  before do
    # If we are using certificates and we reach here then the peer is verified and cannot be spoofed. ALWAYS use certificates OR ELSE!!!
    # If we are not using certificates then the hostname can be spoofed but this will still keep out most casual mischief.
    if (SETTINGS.trusted_hosts and !SETTINGS.trusted_hosts.empty?) and
      !SETTINGS.trusted_hosts.include?(request.env["REMOTE_HOST"].downcase)
      log_halt 403, "Untrusted client #{request.env["REMOTE_HOST"].downcase} attempted to access #{request.path_info}. Check :trusted_hosts: in settings.yml"
    end
  end
end
