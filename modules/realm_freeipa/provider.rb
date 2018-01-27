require 'gssapi'
require 'proxy/kerberos'
require 'uri'
require 'xmlrpc/client'
require 'net/https'

module Proxy::FreeIPARealm
  class Provider
    include Proxy::Log
    include Proxy::Util
    include Proxy::Kerberos

    attr_reader :remove_dns, :ipa_config

    def initialize(ipa_config, keytab_path, principal, remove_dns)
      @ipa_config = ipa_config
      @keytab_path = keytab_path
      @principal = principal
      @remove_dns = remove_dns
    end

    def ipa
      @ipa ||= configure_ipa
    end

    def configure_ipa
      # Get krb5 token
      init_krb5_ccache @keytab_path, @principal
      gssapi = GSSAPI::Simple.new(ipa_config.host, "HTTP")
      token = gssapi.init_context

      login = Net::HTTP.new(ipa_config.host, 443)
      login.use_ssl = true
      login.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new("/ipa/session/login_kerberos", 'Authorization'=>"Negotiate #{strict_encode64(token)}", 'Referer' => ipa_config.uri)
      response = login.request(request)
      cookie = response['Set-Cookie']

      # FreeIPA API returns some nils, Ruby XML-RPC doesn't like this
      XMLRPC::Config.module_eval { const_set(:ENABLE_NIL_PARSER, true) }
      ipa = XMLRPC::Client.new2(ipa_config.scheme + "://" + ipa_config.host + "/ipa/session/xml")
      # For some reason ipa insists on having 'Referer' header to be present...
      ipa.http_header_extra={ 'Referer' => ipa_config.uri, 'Content-Type' => 'text/xml; charset=utf-8' }
      ipa.cookie = cookie # set the session cookie

      ipa
    end

    def check_realm realm
      raise Exception.new "Unknown realm #{realm}" unless realm.casecmp(ipa_config.realm).zero?
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

    def create realm, hostname, params
      check_realm realm

      # Send params to FreeIPA, may want to send more than one in the future
      setattr = params.has_key?('userclass') ? ["userclass=#{params['userclass']}"] : []

      host = find(hostname)
      if host.nil?
        result = do_host_create(hostname, setattr)
      elsif params[:rebuild] == "true"
        result = do_host_rebuild(hostname, setattr, host["result"]["has_keytab"])
      else
        result = do_host_modify(hostname, setattr)
      end

      result['result'].to_json
    rescue => e
      if e.message =~ /no modifications/
        JSON.pretty_generate({"message" => "nothing to do"})
      else
        raise
      end
    end

    def do_host_rebuild(hostname, setattr, has_keytab)
      options = {:random => 1}
      options[:setattr] = setattr unless setattr.nil?

      ipa_call("host_disable", [hostname]) if has_keytab
      ipa_call('host_mod', [hostname], options)
    end

    def do_host_modify(hostname, setattr)
      options = {}
      options[:setattr] = setattr unless setattr.nil?
      ipa_call('host_mod', [hostname], options)
    end

    def do_host_create(hostname, setattr)
      options = {:random => 1, :force => 1}
      options[:setattr] = setattr unless setattr.nil?
      ipa_call('host_add', [hostname], options)
    end

    def delete realm, hostname
      check_realm realm
      begin
        result = ipa_call("host_del", [hostname], "updatedns" => remove_dns)
      rescue
        if remove_dns
          # If the host doesn't have a DNS record (e.g. deleting a system in Foreman before it's built)
          # the above call will fail.  Try again with updatedns => false
          result = ipa_call("host_del", [hostname], "updatedns" => false)
        else
          raise
        end
      end

      result.to_json
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
      logger.debug "Making IPA call: #{args}"
      self.class.ensure_utf(ipa.call(*args))
    end
  end
end
