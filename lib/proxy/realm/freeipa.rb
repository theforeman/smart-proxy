require 'gssapi'
require 'helpers'
require 'proxy/kerberos'
require 'proxy/util'
require 'uri'
require 'xmlrpc/client'

module Proxy::Realm
  class FreeIPA < Client
    include Proxy::Kerberos
    include Proxy::Util

    IPA_CONFIG = "/etc/ipa/default.conf"

    def initialize
      errors = []
      errors << "keytab not configured"                      unless SETTINGS.realm_keytab
      errors << "keytab not found: #{SETTINGS.realm_keytab}" unless SETTINGS.realm_keytab && File.exist?(SETTINGS.realm_keytab)
      errors << "principal not configured"                   unless SETTINGS.realm_principal

      logger.info "freeipa: realm keytab is '#{SETTINGS.realm_keytab}' and using principal '#{SETTINGS.realm_principal}'"

      # Get FreeIPA Configuration
      if File.exist?(IPA_CONFIG)
        File.readlines(IPA_CONFIG).each do |line|
          if line =~ /xmlrpc_uri/
            @ipa_server = URI.parse line.split("=")[1].strip
            logger.info "freeipa: server is #{@ipa_server}"
          elsif line =~ /realm/
            @realm_name = line.split("=")[1].strip
            logger.info "freeipa: realm #{@realm_name}"
          end
        end
      else
        errors << "unable to read FreeIPA configuration: #{IPA_CONFIG}"
      end

      errors << "unable to parse client configuration" unless @ipa_server && @realm_name

      if errors.empty?
        # Get krb5 token
        init_krb5_ccache SETTINGS.realm_keytab, SETTINGS.realm_principal
        gssapi = GSSAPI::Simple.new(@ipa_server.host, "HTTP")
        token = gssapi.init_context

        # FreeIPA API returns some nils, Ruby XML-RPC doesn't like this
        XMLRPC::Config.module_eval { const_set(:ENABLE_NIL_PARSER, true) }

        @ipa = XMLRPC::Client.new2(@ipa_server.to_s)
        @ipa.http_header_extra={ 'Authorization'=>"Negotiate #{strict_encode64(token)}",
                                 'Referer' => @ipa_server.to_s,
                                 'Content-Type' => 'text/xml; charset=utf-8'
                               }
      else
        raise Proxy::Realm::Error.new errors.join(", ")
      end
    end

    def check_realm realm
      raise Proxy::Realm::Error.new "Unknown realm #{realm}" unless realm.casecmp(@realm_name).zero?
    end

    def create realm, params
      check_realm realm

      options = { :setattr => [] }

      # Send params to FreeIPA, may want to send more than one in the future
      %w(userclass).each do |attr|
        options[:setattr] << "#{attr}=#{params[attr]}" if params.has_key? attr
      end

      # Determine if we're updating a host or creating a new one
      if @ipa.call("host_find", [params[:hostname]])["count"].zero?
        options.merge!(:random => 1, :force => 1)
        operation = "host_add"
      else
        # If the host is being rebuilt, disable it in order to revoke existing certs, keytabs, etc.
        if params[:rebuild] == "true"
          begin
            logger.info "Attempting to disable host #{params[:hostname]} in FreeIPA"
            @ipa.call("host_disable", [params[:hostname]])
          rescue => e
            logger.info "Disabling failed for host #{params[:hostname]}: #{e}.  Continuing anyway."
          end
        end
        options.merge!(:random => 1)
        operation = "host_mod"
      end

      begin
        result = @ipa.call(operation, [params[:hostname]], options)
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
      JSON.pretty_generate(@ipa.call("host_del", [hostname], {"updatedns" => SETTINGS.freeipa_remove_dns}))
    end
  end
end
