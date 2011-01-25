class SmartProxy
  put "/puppet/ca/autosign" do
    content_type :json
    certnames = params[:cert]
    begin
      case params[:state]
      when 'enable'
        return certnames.collect{|certname| Proxy::PuppetCA.sign(certname)}.to_json
      when 'disable'
        return certnames.collect {|certname| Proxy::PuppetCA.disable(certname)}.to_json
      else
        log_halt 400, "Puppet CA: Unknown state: Neither enable or disable"
      end
    rescue => e
      log_halt 500, "Failed to autosign #{params[:cert]}" + e.to_s
    end
  end

  delete "/puppet/ca/:cert" do
    begin
      content_type :json
      certnames = params[:cert]
      certnames.collect {|certname| Proxy::PuppetCA.clean(certname)}.to_json
    rescue => e
      log_halt 500, "Failed to remove certificate(s) for #{certnames}" + e.to_s
    end
  end
end