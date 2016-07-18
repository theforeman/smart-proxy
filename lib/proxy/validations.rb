require 'ipaddr'

module Proxy::Validations
  include Proxy::Log

  MAC_REGEXP_48BIT = /\A([a-f0-9]{1,2}:){5}[a-f0-9]{1,2}\z/i
  MAC_REGEXP_64BIT = /\A([a-f0-9]{1,2}:){19}[a-f0-9]{1,2}\z/i

  class Error < RuntimeError; end
  private

  def valid_mac? mac
    return false if mac.nil?
    return true if mac =~ MAC_REGEXP_48BIT || mac =~ MAC_REGEXP_64BIT
    false
  end

  # validates the ip address
  def validate_ip ip
    IPAddr.new(ip)
    ip
  rescue invalid_address_error
    raise Error, "Invalid IP Address #{ip}"
  end

  # we may not want to raise error in some cases bu skip the ip instead
  def soft_validate_ip ip
    IPAddr.new(ip)
    ip
  rescue invalid_address_error
    logger.debug("Invalid IPv6 address #{ip} detected, skipping")
    nil
  end

  # validate prefix for IPv6 subnet
  def validate_v6_prefix prefix
    prefix = prefix.to_i
    raise Error, "Invalid IPv6 prefix #{prefix}" if (prefix < 1 || prefix > 127)
    prefix
  end

  # validates the mac
  def validate_mac mac
    raise Error, "Invalid MAC #{mac}" unless valid_mac?(mac)
    mac.downcase
  end

  def validate_mac_or_uid mac, uid
    raise Error, "MAC or UID must be present" if [mac, uid].none?
    raise Error, "Only one of MAC, UID must be present" if [mac, uid].all?
    if mac
      { :mac => validate_mac(mac) }
    else
      { :uid => uid }
    end
  end

  def validate_subnet subnet
    raise Error, "Invalid Subnet #{subnet}" unless subnet.is_a?(Proxy::DHCP::Subnet)
    subnet
  end

  def validate_server server
    raise Proxy::DHCP::Error, "Invalid Server #{server}" unless server.is_a?(Proxy::DHCP::Server)
    server
  end

  def validate_record record
    raise Proxy::DHCP::Error, "Invalid Record #{record}" unless record.is_a?(Proxy::DHCP::Record)
    record
  end

  private

  def invalid_address_error
    # IPAddr::InvalidAddressError is undefined for ruby 1.9
    return IPAddr::InvalidAddressError if IPAddr.const_defined?('InvalidAddressError')
    ArgumentError
  end
end
