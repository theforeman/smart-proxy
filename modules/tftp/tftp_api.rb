require 'tftp/server'
require 'proxy/validations'

module Proxy::TFTP
  class Api < ::Sinatra::Base
    include ::Proxy::Log
    include ::Proxy::Validations
    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client
    VARIANTS = ["Syslinux", "Pxelinux", "Pxegrub2", "Ztp", "Poap", "Ipxe"].freeze

    helpers do
      def instantiate(variant, mac = nil)
        # Filenames must end in a hex representation of a mac address but only if mac is not empty
        log_halt 403, "Invalid MAC address: #{mac}"                  unless valid_mac?(mac) || mac.nil?
        log_halt 403, "Unrecognized pxeboot config type: #{variant}" unless VARIANTS.include?(variant.capitalize)
        Object.const_get("Proxy").const_get('TFTP').const_get(variant.capitalize).new
      end

      def with_host_config_lock(mac)
        lock = log_halt(400, "TFTP: Failed to reserve host configuration: ") do
          Proxy::TFTP.try_lock_host_config(mac)
        end
        log_halt(409, "TFTP: Host configuration is already being updated for #{mac}") unless lock
        yield
      ensure
        Proxy::FileLock.unlock(lock) if lock
      end

      def create(variant, mac, os: nil, release: nil, arch: nil, bootfile_suffix: nil)
        tftp = instantiate variant, mac
        with_host_config_lock(mac) do
          read_directories =
            if tftp.is_a?(Proxy::TFTP::Pxegrub2)
              log_halt(409, "TFTP: Failed to reserve bootloader universe files: ") do
                Proxy::TFTP.bootloader_universe_directories(os: os, release: release, arch: arch)
              end
            else
              []
            end

          log_halt(nil, "TFTP: Failed to reserve bootloader universe files: ") do
            Proxy::TFTP::DIR_LOCK.with_read(read_directories) do
              if %w[universe_archive universe_kernel universe_initrd universe_source_digest].any? { |key| params.key?(key) }
                log_halt(409, "TFTP: Failed to validate bootloader universe files: ") do
                  Proxy::TFTP.validate_universe_boot_files!(
                    os: os, release: release, arch: arch,
                    archive: params[:universe_archive], kernel: params[:universe_kernel],
                    initrd: params[:universe_initrd], source_digest: params[:universe_source_digest]
                  )
                end
              end
              # Preserve the usual 400 response for setup failures, while allowing
              # a busy-universe error to provide its specific 409 status.
              log_halt(nil, "TFTP: Failed to setup host specific bootloader directory: ") do
                tftp.setup_bootloader(mac: mac, os: os, release: release, arch: arch,
                                      bootfile_suffix: bootfile_suffix,
                                      use_universe: params.key?(:universe_archive) || params.key?('universe_archive'))
              end
              log_halt(400, "TFTP: Failed to create pxe config file: ") { tftp.set(mac, params[:pxeconfig] || params[:syslinux_config]) }
            end
          end
        end
      end

      def delete(variant, mac)
        tftp = instantiate variant, mac
        with_host_config_lock(mac) do
          log_halt(400, "TFTP: Failed to delete pxe config file: ") { tftp.del(mac) }
        end
      end

      def create_default(variant)
        tftp = instantiate variant
        log_halt(400, "TFTP: Failed to create PXE default file: ") { tftp.create_default params[:menu] }
      end
    end

    post "/fetch_boot_file" do
      log_halt(400, "TFTP: Failed to fetch boot file: ") { Proxy::TFTP.fetch_boot_file(params[:prefix], params[:path]) }
    end

    post "/fetch_and_process" do
      request_params = parse_json_body.merge(params)
      destination = request_params[:destination] || request_params['destination']
      extract = request_params[:extract] || request_params['extract']
      source = request_params[:source] || request_params['source']
      log_halt(nil, "TFTP: Failed to fetch and process boot file: ") do
        if extract
          Proxy::TFTP.fetch_boot_file(nil, nil, extract)
        else
          Proxy::TFTP.fetch_boot_file(destination, source, nil, exact_destination: true)
        end
      end
    end

    post "/:variant/create_default" do |variant|
      create_default variant
    end

    get "/:variant/:mac" do |variant, mac|
      tftp = instantiate variant, mac
      with_host_config_lock(mac) do
        log_halt(404, "TFTP: Failed to retrieve pxe config file: ") { tftp.get(mac) }
      end
    end

    post "/:variant/:mac" do |variant, mac|
      create variant, mac, os: params[:targetos], release: params[:release], arch: params[:arch], bootfile_suffix: params[:bootfile_suffix]
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
      {"serverName" => Proxy::TFTP::Plugin.settings.tftp_servername || ""}.to_json
    end
  end
end
