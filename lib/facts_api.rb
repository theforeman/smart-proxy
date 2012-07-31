class SmartProxy < Sinatra::Base
  get "/facts" do
    begin
      content_type :json
      Facter.to_hash.to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/facts/:fact" do
    begin
      content_type :json
      fact_value = Facter.fact(params[:fact].to_sym).value
      log_halt 404, "Fact #{params[:fact]} not found" unless fact_value
      { params[:fact].to_sym => fact_value }.to_json
    rescue => e
      log_halt 400, e
    end
  end

end
