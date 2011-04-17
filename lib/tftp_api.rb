class SmartProxy
  post "/tftp/fetch_boot_file" do
    begin
      Proxy::TFTP.fetch_boot_file(params[:prefix], params[:path])
    rescue => e
      log_halt 400, e.to_s
    end
  end

  post "/tftp/create_default" do
    begin
      log_halt 400, "Failed to create PXE default file" unless Proxy::TFTP.create_default params[:menu]
    rescue
      log_halt 400, e.to_s
    end
  end

  # create a new TFTP reservation
  post "/tftp/:mac" do
    mac = params[:mac]
    syslinux = params[:syslinux_config]
    begin
      log_halt 400, "Failed to create a tftp reservation for #{mac}" unless Proxy::TFTP.create(mac, syslinux)
    rescue Exception => e
      log_halt 400, e.to_s
    end
  end

  # Get the value for next_server
  get "/tftp/serverName" do
     {"serverName" => (SETTINGS.tftp_servername || "")}.to_json
  end


  # delete a record from a network
  delete "/tftp/:mac" do
    begin
      log_halt 400, "Failed to remove tftp reservation for #{params[:mac]}" unless Proxy::TFTP.remove(params[:mac])
    rescue => e
      log_halt 400, e.to_s
    end
  end

end
