class SmartProxy

  helpers do
    def instantiate variant, mac=nil
      # Filenames must end in a hex representation of a mac address but only if mac is not empty
      log_halt 403, "Invalid MAC address: #{mac}"                  unless mac =~ /^(?:[\da-f][\da-f][:-]?){6}$/i or mac.nil?
      log_halt 403, "Unrecognized pxeboot config type: #{variant}" unless defined? variant.capitalize
      eval "Proxy::TFTP::#{variant.capitalize}.new"
    end

    def create variant, mac
      tftp = instantiate variant, mac
      log_halt(400, "TFTP: Failed to create pxe config file: ") {tftp.set(mac, (params[:pxeconfig] || params[:syslinux_config]))}
    end
    def delete variant, mac
      tftp = instantiate variant, mac
      log_halt(400, "TFTP: Failed to delete pxe config file: ") {tftp.del(mac)}
    end
    def create_default variant
      tftp = instantiate variant
      log_halt(400, "TFTP: Failed to create PXE default file: ") { tftp.create_default params[:menu]}
    end
  end

  post "/tftp/fetch_boot_file" do
    log_halt(400, "TFTP: Failed to fetch boot file: ") {Proxy::TFTP.fetch_boot_file(params[:prefix], params[:path])}
  end

  post "/tftp/:variant/create_default" do |variant|
    create_default variant
  end

  get "/tftp/:variant/:mac" do |variant, mac|
    tftp = instantiate variant, mac
    log_halt(404, "TFTP: Failed to retrieve pxe config file: ") {tftp.get(mac)}
  end

  post "/tftp/:variant/:mac" do |variant, mac|
    create variant, mac
  end

  delete "/tftp/:variant/:mac" do |variant, mac|
    delete variant, mac
  end

  post "/tftp/create_default" do
    create_default "syslinux"
  end

  # Create a new TFTP reservation
  post "/tftp/:mac" do |mac|
    create "syslinux", mac
  end

  # Delete a record from a network
  delete("/tftp/:mac") do |mac|
    delete "syslinux", mac
  end

  # Get the value for next_server
  get "/tftp/serverName" do
     {"serverName" => (SETTINGS.tftp_servername || "")}.to_json
  end

end
