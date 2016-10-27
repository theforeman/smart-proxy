require 'proxy/validations'

module Proxy::TFTP
  class Api < ::Sinatra::Base
    extend Proxy::TFTP::DependencyInjection
    include ::Proxy::Log
    include ::Proxy::Validations
    helpers ::Proxy::Helpers

    inject_attr :http_downloads, :boot_file_downloader

    authorize_with_trusted_hosts
    authorize_with_ssl_client
    VARIANTS = ["Syslinux", "Pxelinux", "Pxegrub", "Pxegrub2", "Ztp", "Poap", "Ipxe"].freeze

    helpers do
      def instantiate variant, mac=nil
        # Filenames must end in a hex representation of a mac address but only if mac is not empty
        log_halt 403, "Invalid MAC address: #{mac}"                  unless valid_mac?(mac) || mac.nil?
        log_halt 403, "Unrecognized pxeboot config type: #{variant}" unless VARIANTS.include?(variant.capitalize)
        Object.const_get("Proxy").const_get('TFTP').const_get(variant.capitalize).new
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

    post "/fetch_boot_file" do
      log_halt(400, "TFTP: Failed to fetch boot file: ") {boot_file_downloader.download(params[:prefix], params[:path])}
    end

    get "/fetch_boot_file_status/:id" do |id|
      content_type :json
      status = boot_file_downloader.status(id)
      log_halt 404, "Could not find status for download '#{id}'" if status.nil?
      status.to_hash.to_json
    end

    post "/:variant/create_default" do |variant|
      create_default variant
    end

    get "/:variant/:mac" do |variant, mac|
      tftp = instantiate variant, mac
      log_halt(404, "TFTP: Failed to retrieve pxe config file: ") {tftp.get(mac)}
    end

    post "/:variant/:mac" do |variant, mac|
      create variant, mac
    end

    delete "/:variant/:mac" do |variant, mac|
      delete variant, mac
    end

    post "/create_default" do
      create_default "syslinux"
    end

    post "/:mac" do |mac|
      create "syslinux", mac
    end

    delete("/:mac") do |mac|
      delete "syslinux", mac
    end

    # Get the value for next_server
    get "/serverName" do
       {"serverName" => (Proxy::TFTP::Plugin.settings.tftp_servername || "")}.to_json
    end
  end
end
