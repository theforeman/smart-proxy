class SmartProxy
  post "/tftp/fetch_boot_file" do
    begin
      Proxy::TFTP.fetch_boot_file(params[:prefix], params[:path])
    rescue => e
      halt 400, e.to_s
    end
  end

  # create a new TFTP reservation
  post "/tftp/:mac" do
    mac = params[:mac]
    syslinux = params[:syslinux_config]
    begin
      halt 400, "Failed to create a tftp reservation for #{mac}" unless Proxy::TFTP.create(mac, syslinux)
    rescue Exception => e
      halt 400, e.to_s
    end
  end

  # delete a record from a network
  delete "/tftp/:mac" do
    begin
      halt 400, "Failed to remove tftp reservation for #{params[:mac]}" unless Proxy::TFTP.remove(params[:mac])
    rescue => e
      halt 400, e.to_s
    end
  end
end
