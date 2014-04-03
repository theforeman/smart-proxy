class SmartProxy < Sinatra::Base
  def realm_setup
    raise "Smart Proxy is not configured to support Realm" unless SETTINGS.realm

    case SETTINGS.realm_provider
      when "freeipa"
        require 'proxy/realm/freeipa'
        @realm = Proxy::Realm::FreeIPA.new
      else
        log_halt 400, "Unrecognized or missing Realm provider: #{SETTINGS.realm_provider.nil? ? "MISSING" : SETTINGS.realm_provider}"
    end
    rescue => e
      log_halt 400, e
  end

  before do
    realm_setup if request.path_info =~ /realm/
  end

  post "/realm/:realm/?" do
    begin
      content_type :json
      @realm.create params[:realm], params
    rescue Exception => e
      log_halt 400, e
    end
  end

  delete "/realm/:realm/:hostname/?" do
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
