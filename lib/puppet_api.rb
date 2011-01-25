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
end