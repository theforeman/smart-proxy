module Proxy::Realm
  class Api < Sinatra::Base
    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    def realm_setup
      raise "Smart Proxy is not configured to support Realm" unless Proxy::Realm::Plugin.settings.enabled

      case Proxy::Realm::Plugin.settings.realm_provider
        when "freeipa"
          require 'realm/freeipa'
          @realm = Proxy::Realm::FreeIPA.new
        else
          log_halt 400, "Unrecognized Realm provider: #{Proxy::Realm::Plugin.settings.realm_provider}"
      end
      rescue => e
        log_halt 400, e
    end

    before do
      realm_setup
    end

    post "/:realm/?" do
      begin
        content_type :json
        @realm.create params[:realm], params
      rescue Exception => e
        log_halt 400, e
      end
    end

    delete "/:realm/:hostname/?" do
      begin
        content_type :json
        @realm.delete params[:realm], params[:hostname]
      rescue Proxy::Realm::NotFound => e
        log halt 404, "#{e}"
      rescue Exception => e
        log_halt 400, e
      end
    end
  end
end
