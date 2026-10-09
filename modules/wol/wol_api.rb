require 'proxy/validations'
require 'wol/wol_packet_sender'

class Proxy::WolApi < Sinatra::Base
  include Proxy::Validations
  helpers ::Proxy::Helpers
  authorize_with_trusted_hosts
  authorize_with_ssl_client

  post "/" do
    content_type :json

    # Parse JSON body and merge with URL parameters
    body_params = parse_json_body
    all_params = params.merge(body_params)

    # Get MAC address from either URL params or JSON body
    mac_address = all_params[:mac_address] || all_params['mac_address']

    logger.debug "WoL API - Final MAC address: #{mac_address}"

    begin
      mac_address = validate_mac(mac_address)
    rescue Proxy::Validations::InvalidMACAddress => e
      log_halt 400, "Invalid MAC address provided: #{e.message}"
    end

    # Send Wake-on-LAN magic packet
    begin
      Proxy::Wol::WolPacketSender.send_magic_packet(mac_address)

      # Log the attempt
      logger.info "Wake-on-LAN packet sent to MAC address: #{mac_address}"

      { :status => "success", :message => "Wake-on-LAN packet sent successfully", :mac_address => mac_address }.to_json
    rescue => e
      logger.error "Failed to send Wake-on-LAN packet to #{mac_address}: #{e.message}"
      log_halt 500, "Failed to send Wake-on-LAN packet: #{e.message}"
    end
  end
end
