class SmartProxy
  get "/puppet/ca" do
    content_type :json
    begin
      Proxy::PuppetCA.list.to_json
    rescue => e
      log_halt 406, "Failed to list certificates: #{e}"
    end
  end

  get "/puppet/ca/autosign" do
    content_type :json
    begin
      Proxy::PuppetCA.autosign_list.to_json
    rescue => e
      log_halt 406, "Failed to list autosign entries: #{e}"
    end
  end

  post "/puppet/ca/autosign/:certname" do
    content_type :json
    certname = params[:certname]
    begin
      Proxy::PuppetCA.autosign(certname)
    rescue => e
      log_halt 406, "Failed to enable autosign for #{certname}: #{e}"
    end
  end

  delete "/puppet/ca/autosign/:certname" do
    content_type :json
    certname = params[:certname]
    begin
      Proxy::PuppetCA.disable(certname)
    rescue => e
      log_halt 406, "Failed to remove autosign for #{certname}: #{e}"
    end
  end

  post "/puppet/ca/:certname" do
    content_type :json
    certname = params[:certname]
    begin
      Proxy::PuppetCA.sign(certname)
    rescue => e
      log_halt 406, "Failed to enable autosign for #{certname}: #{e}"
    end
  end
  delete "/puppet/ca/:certname" do
    begin
      content_type :json
      certname = params[:certname]
      Proxy::PuppetCA.clean(certname)
    rescue => e
      log_halt 406, "Failed to remove certificate(s) for #{certname}: #{e}"
    end
  end
end
