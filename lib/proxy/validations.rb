require 'ipaddr'
require 'resolv'

module Proxy::Validations
  MAC_REGEXP_48BIT = /\A([a-f0-9]{1,2}:){5}[a-f0-9]{1,2}\z/i
  MAC_REGEXP_64BIT = /\A([a-f0-9]{1,2}:){19}[a-f0-9]{1,2}\z/i

  class Error < RuntimeError; end
  class InvalidIPAddress < Error; end
  class InvalidMACAddress < Error; end
  class InvalidSubnet < Error; end

  private

  def valid_mac?(mac)
    return false if mac.nil?
    return true if mac =~ MAC_REGEXP_48BIT || mac =~ MAC_REGEXP_64BIT
    false
  end

  def valid_ip?(ip)
    valid_ip4?(ip) || valid_ip6?(ip)
  end

  def valid_ip4?(ip)
    Resolv::IPv4::Regex.match?(ip)
  end

  def valid_ip6?(ip)
    Resolv::IPv6::Regex.match?(ip)
  end

  # validates the ip address
  def validate_ip(ip, version = nil)
    valid = false
    valid = valid_ip4?(ip) if version == 4
    valid = valid_ip6?(ip) if version == 6
    valid = valid_ip?(ip) if version.nil?
    raise InvalidIPAddress, "Invalid IP Address #{ip}" unless valid
    ip
  end

  # validates the mac
  def validate_mac(mac)
    raise InvalidMACAddress, "Invalid MAC #{mac}" unless valid_mac?(mac)
    mac.downcase
  end

  def validate_subnet(subnet)
    raise InvalidSubnet, "Invalid Subnet #{subnet}" unless subnet.is_a?(Proxy::DHCP::Subnet)
    subnet
  end

  def validate_server(server)
    raise Proxy::DHCP::Error, "Invalid Server #{server}" unless server.is_a?(Proxy::DHCP::Server)
    server
  end

  def validate_record(record)
    raise Proxy::DHCP::Error, "Invalid Record #{record}" unless record.is_a?(Proxy::DHCP::Record)
    record
  end
end
