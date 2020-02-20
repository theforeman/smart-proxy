module Proxy::Validations
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
    raise Error, "Invalid IP Address #{ip}" unless ip =~ /(\d{1,3}\.){3}\d{1,3}/
    ip
  end

  # validates the mac
  def validate_mac mac
    raise Error, "Invalid MAC #{mac}" unless valid_mac?(mac)
    mac.downcase
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
end
