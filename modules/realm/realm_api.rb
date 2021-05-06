module Proxy::Realm
  class Api < Sinatra::Base
    extend Proxy::Realm::DependencyInjection

    helpers ::Proxy::Helpers

    inject_attr :realm_provider_impl, :realm_provider

    post "/:realm/?" do
      content_type :json
      realm_provider.create(params[:realm], params[:hostname], params)
    rescue Exception => e
      log_halt 400, e
    end

    delete "/:realm/:hostname/?" do
      log_halt 404, "Host #{params[:hostname]} not found in realm" unless realm_provider.find(params[:hostname])
      content_type :json
      realm_provider.delete(params[:realm], params[:hostname])
    rescue Exception => e
      log_halt 400, e
    end
  end
end
