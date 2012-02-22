class SmartProxy
  post "/puppet/run" do
    hosts = params[:nodes]
    begin
      log_halt 400, "Failed puppet run: No nodes defined" unless hosts
      log_halt 500, "Failed puppet run: Check Log files" unless Proxy::Puppet.run hosts
    rescue => e
      log_halt 500, "Failed puppet run: #{e}"
    end
  end

  get "/puppet/environments" do
    content_type :json
    begin
      Proxy::Puppet::Environment.all.to_json
    rescue => e
      log_halt 406, "Failed to list puppet environments: #{e}"
    end
  end

  get "/puppet/environments/:environment" do
    content_type :json
    begin
      env = Proxy::Puppet::Environment.find(params[:environment])
      log_halt 404, "Not found" unless env
      env.to_json
    rescue => e
      log_halt 406, "Failed to show puppet environment: #{e}"
    end
  end

  get "/puppet/environments/:environment/classes" do
    content_type :json
    begin
      env = Proxy::Puppet::Environment.find(params[:environment])
      log_halt 404, "Not found" unless env
      env.classes.map{|k| {k.to_s => { :name => k.name, :module => k.module} } }.to_json
    rescue => e
      log_halt 406, "Failed to show puppet classes: #{e}"
    end
  end

end