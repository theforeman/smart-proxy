require 'gssapi'
require 'proxy/kerberos'
require 'uri'
require 'xmlrpc/client'
require 'realm/client'
require 'net/https'

module Proxy::Realm
  class FreeIPA < Client
    include Proxy::Kerberos
    include Proxy::Util

    IPA_CONFIG = "/etc/ipa/default.conf"

    def initialize
      errors = []
      errors << "keytab not configured"                      unless Proxy::Realm::Plugin.settings.realm_keytab
      errors << "keytab not found: #{Proxy::Realm::Plugin.settings.realm_keytab}" unless Proxy::Realm::Plugin.settings.realm_keytab && File.exist?(Proxy::Realm::Plugin.settings.realm_keytab)
      errors << "principal not configured"                   unless Proxy::Realm::Plugin.settings.realm_principal

      logger.debug "freeipa: realm keytab is '#{Proxy::Realm::Plugin.settings.realm_keytab}' and using principal '#{Proxy::Realm::Plugin.settings.realm_principal}'"

      # Get FreeIPA Configuration
      if File.exist?(IPA_CONFIG)
        File.readlines(IPA_CONFIG).each do |line|
          if line =~ /xmlrpc_uri/
            @ipa_server = URI.parse line.split("=")[1].strip
            logger.debug "freeipa: server is #{@ipa_server}"
          elsif line =~ /realm/
            @realm_name = line.split("=")[1].strip
            logger.debug "freeipa: realm #{@realm_name}"
          end
        end
      else
        errors << "unable to read FreeIPA configuration: #{IPA_CONFIG}"
      end

      errors << "unable to parse client configuration" unless @ipa_server && @realm_name

      if errors.empty?
        # Get krb5 token
        init_krb5_ccache Proxy::Realm::Plugin.settings.realm_keytab, Proxy::Realm::Plugin.settings.realm_principal
        @gssapi = GSSAPI::Simple.new(@ipa_server.host, "HTTP")
        token = @gssapi.init_context

        login = Net::HTTP.new(@ipa_server.host, 443)
        login.use_ssl = true
        login.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Post.new("/ipa/session/login_kerberos", 'Authorization'=>"Negotiate #{strict_encode64(token)}", 'Referer' => @ipa_server.to_s)
        response = login.request(request)
        cookie = response['Set-Cookie']

        # FreeIPA API returns some nils, Ruby XML-RPC doesn't like this
        XMLRPC::Config.module_eval { const_set(:ENABLE_NIL_PARSER, true) }
        @ipa = XMLRPC::Client.new2(@ipa_server.scheme + "://" + @ipa_server.host + "/ipa/session/xml")
        # For some reason ipa insists on having 'Referer' header to be present...
        @ipa.http_header_extra={ 'Referer' => @ipa_server.to_s, 'Content-Type' => 'text/xml; charset=utf-8' }
        @ipa.cookie = cookie # set the session cookie
      else
        raise Proxy::Realm::Error.new errors.join(", ")
      end
    end

    def check_realm realm
      raise Proxy::Realm::Error.new "Unknown realm #{realm}" unless realm.casecmp(@realm_name).zero?
    end

    def find hostname
      ipa_call("host_show", [hostname])
    rescue XMLRPC::FaultException => e
      if e.message =~ /not found/
        nil
      else
        raise
      end
    end

    def create realm, params
      check_realm realm

      options = { :setattr => [] }

      # Send params to FreeIPA, may want to send more than one in the future
      %w(userclass).each do |attr|
        options[:setattr] << "#{attr}=#{params[attr]}" if params.has_key? attr
      end

      # Determine if we're updating a host or creating a new one
      host = find params[:hostname]
      if host.nil?
        options[:random] = 1
        options[:force] = 1
        operation = "host_add"
      else
        if params[:rebuild] == "true"
          options[:random] = 1
          # If the host is being rebuilt and is already enrolled, then
          # disable it in order to revoke existing certs, keytabs, etc.
          if host["result"]["has_keytab"]
            logger.debug "Attempting to disable host #{params[:hostname]} in FreeIPA"
            ipa_call("host_disable", [params[:hostname]])
          end
        end
        operation = "host_mod"
      end

      begin
        result = ipa_call(operation, [params[:hostname]], options)
      rescue => e
        if e.message =~ /no modifications/
          result = {"result" => {"message" => "nothing to do"}}
        else
          raise
        end
      end

      JSON.pretty_generate(result["result"])
    end

    def delete realm, hostname
      check_realm realm
      raise Proxy::Realm::NotFound, "Host #{hostname} not found in realm!" unless find hostname
      begin
        result = ipa_call("host_del", [hostname], "updatedns" => Proxy::Realm::Plugin.settings.freeipa_remove_dns)
      rescue
        if Proxy::Realm::Plugin.settings.freeipa_remove_dns
          # If the host doesn't have a DNS record (e.g. deleting a system in Foreman before it's built)
          # the above call will fail.  Try again with updatedns => false
          result = ipa_call("host_del", [hostname], "updatedns" => false)
        else
          raise
        end
      end
      JSON.pretty_generate(result)
    end

    def self.ensure_utf(object)
      case object
      when String
        if object.respond_to?(:force_encoding)
          object.dup.force_encoding('UTF-8')
        else
          object
        end
      when Hash
        object.reduce({}) do |h, (key, val)|
          h.update(ensure_utf(key) => ensure_utf(val))
        end
      when Array
        object.map { |val| ensure_utf(val) }
      else
        object
      end
    end

    private

    def ipa_call(*args)
      self.class.ensure_utf(@ipa.call(*args))
    end
  end
end
