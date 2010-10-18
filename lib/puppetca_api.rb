put "/puppet/ca/autosign" do
  content_type :json
  certnames = params[:cert]
  case params[:state]
  when 'enable'
    return certnames.collect{|certname| Proxy::PuppetCA.sign(certname)}.to_json
  when 'disable'
    return certnames.collect {|certname| Proxy::PuppetCA.disable(certname)}.to_json
  else
    render 400, "Unknown state"
  end
end

delete "/puppet/ca/:cert" do
  content_type :json
  certnames = params[:cert]
  certnames.collect {|certname| Proxy::PuppetCA.clean(certname)}.to_json
end


