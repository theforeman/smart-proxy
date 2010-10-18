post "/tftp/fetch_boot_file" do
  begin
    Proxy::TFTP.fetch_boot_file(params[:prefix], params[:path])
  rescue => e
    halt 400, e
  end
end

# create a new TFTP reservation
post "/tftp/:mac" do
  mac = params[:mac]
  syslinux = params[:syslinux_config]
  begin
    halt 400 unless Proxy::TFTP.create(mac, syslinux)
  rescue Exception => e.to_s
    halt 400, e
  end
end

# delete a record from a network
delete "/tftp/:mac" do
    halt 400 unless Proxy::TFTP.remove(params[:mac])
end

