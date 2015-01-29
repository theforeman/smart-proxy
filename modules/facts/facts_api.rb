class Proxy::FactsApi < Sinatra::Base
  helpers ::Proxy::Helpers
  authorize_with_trusted_hosts
  authorize_with_ssl_client

  get "/?" do
    begin
      content_type :json
      Facter.clear
      Facter.to_hash.to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/:fact" do
    begin
      content_type :json
      Facter.clear
      fact_value = Facter.fact(params[:fact].to_sym).value
      log_halt 404, "Fact #{params[:fact]} not found" unless fact_value
      { params[:fact].to_sym => fact_value }.to_json
    rescue => e
      log_halt 400, e
    end
  end

end
