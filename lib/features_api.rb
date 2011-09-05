class SmartProxy < Sinatra::Base
  get "/features" do
    begin
      @features = Proxy.features.sort
      if request.accept.include?("application/json")
        content_type :json
        @features.to_json
      else
        erb :"features/index"
      end
    rescue => e
      log_halt 400, e
    end
  end

  get "/version" do
    begin
      Proxy.version.to_json
    rescue => e
      log_halt 400, e
    end
  end

end
