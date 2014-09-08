require 'rexml/document'

module Proxy::Virsh
  include Proxy::Log
  include Proxy::Util

  attr_reader :network

  def dump_xml
    @xml_dump ||= virsh('net-dumpxml', network)
  end

  def find_ip_for_host host
    doc = REXML::Document.new xml = dump_xml
    doc.elements.each("network/dns/host/hostname") do |e|
      if e.text == host
        return e.parent.attributes["ip"]
      end
    end
    raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{host}")
  rescue Exception => e
    msg = "DNS virsh provider error: unable to retrieve virsh info: #{e}"
    logger.error msg
    logger.debug xml if defined?(xml)
    raise Proxy::Dns::Error, msg
  end

  def virsh *params
    unless sudo_cmd = which("sudo", "/usr/bin", "/usr/sbin")
      raise "DNS virsh provider error: sudo binary was not found"
    end

    unless virsh_cmd = which("virsh", "/usr/bin", "/usr/sbin")
      raise "DNS virsh provider error: virsh binary was not found"
    end

    logger.debug command = ([sudo_cmd, virsh_cmd] + params + ['2>&1']).join(' ')
    stdout = `#{command}`
    if $? == 0
      return stdout
    else
      raise "DNS virsh provider error: virsh call failed (#{$?}) - #{stdout}"
    end
  end

  def virsh_update_dns command, hostname, ip
    hostname = escape_for_shell(hostname)
    ip = escape_for_shell(ip)
    net = escape_for_shell(network)
    virsh "net-update", net, command, "dns-host",
      "--xml", "'<host ip=\"#{ip}\"><hostname>#{hostname}</hostname></host>'",
      "--live", "--config"
  rescue Exception => e
    raise Proxy::Dns::Error, "Failed to update DNS: #{e}"
  end

  def virsh_update_dhcp command, mac, ip, name
    mac = escape_for_shell(mac)
    ip = escape_for_shell(ip)
    net = escape_for_shell(network)

    if name
      name = escape_for_shell(name)
      xml = "'<host mac=\"#{mac}\" name=\"#{name}\" ip=\"#{ip}\"/>'"
    else
      xml = "'<host mac=\"#{mac}\" ip=\"#{ip}\"/>'"
    end

    virsh "net-update", net, command, "ip-dhcp-host",
      "--xml", xml, "--live", "--config"
  rescue Exception => e
    raise Proxy::DHCP::Error, "Failed to update DHCP: #{e}"
  end
end
