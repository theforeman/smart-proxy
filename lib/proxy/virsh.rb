module Proxy::Virsh
  include Proxy::Log
  include Proxy::Util

  class Error < RuntimeError; end

  attr_reader :network

  def dump_xml
    @xml_dump ||= virsh('net-dumpxml', network)
  end

  def virsh *params
    unless sudo_cmd = which("sudo", "/usr/bin", "/usr/sbin")
      raise Error, "virsh provider error: sudo binary was not found"
    end

    unless virsh_cmd = which("virsh", "/usr/bin", "/usr/sbin")
      raise Error, "virsh provider error: virsh binary was not found"
    end

    logger.debug command = ([sudo_cmd, virsh_cmd] + params + ['2>&1']).join(' ')
    stdout = `#{command}`
    if $? == 0
      return stdout
    else
      raise Error, "virsh provider error: virsh call failed (#{$?}) - #{stdout}"
    end
  end
end
