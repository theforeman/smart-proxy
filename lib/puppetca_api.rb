class SmartProxy
  get "/puppet/ca/autosign" do
    content_type :json
    begin
      Proxy::PuppetCA.autosign_list.to_json
    rescue => e
      log_halt 500, "Failed to list autosign entries: #{e}"
    end
  end

  post "/puppet/ca/autosign/:certname" do
    content_type :json
    certname = params[:certname]
    begin
      Proxy::PuppetCA.sign(certname).to_json
    rescue => e
      log_halt 500, "Failed to enable autosign for #{params[:certname]}: #{e}"
    end
  end

  delete "/puppet/ca/autosign/:certname" do
    content_type :json
    certname = params[:certname]
    begin
      Proxy::PuppetCA.disable(certname).to_json
    rescue => e
      log_halt 500, "Failed to remove autosign for #{params[:certname]}: #{e}"
    end
  end

  delete "/puppet/ca/:cert" do
    begin
      content_type :json
      certnames = params[:cert]
      certnames.collect {|certname| Proxy::PuppetCA.clean(certname)}.to_json
    rescue => e
      log_halt 500, "Failed to remove certificate(s) for #{certnames} #{e}"
    end
  end
end
