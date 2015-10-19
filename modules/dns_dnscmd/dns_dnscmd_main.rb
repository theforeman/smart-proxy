require 'resolv'
require 'open3'
require 'dns_common/dns_common'

module Proxy::Dns::Dnscmd
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util

    def initialize(a_server = nil, a_ttl = nil)
      super(a_server || ::Proxy::Dns::Dnscmd::Plugin.settings.dns_server,
            a_ttl || ::Proxy::Dns::Plugin.settings.dns_ttl)
    end

    def create_a_record(fqdn, ip)
      if found = dns_find(fqdn)
        raise(Proxy::Dns::Collision, "#{fqdn} is already used by #{found}") if found != ip
      else
        zone = fqdn.sub(/[^.]+./,'')
        msg = "Added DNS entry #{fqdn} => #{ip}"
        cmd = "/RecordAdd #{zone} #{fqdn}. A #{ip}"
        execute(cmd, msg)
      end
    end

    # noop
    def create_ptr_record(fqdn, ip)
      found = dns_find(ip)
      raise(Proxy::Dns::Collision, "#{ip} is already used by #{found}") if found && found != fqdn
      true
    end

    def remove_a_record(fqdn)
      ip = dns_find(fqdn)
      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{fqdn}") unless ip
      zone = fqdn.sub(/[^.]+./,'')
      msg = "Removed DNS entry #{fqdn} => #{ip}"
      cmd = "/RecordDelete #{zone} #{fqdn}. A /f"
      execute(cmd, msg)
    end

    # noop
    def remove_ptr_record(ip)
      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{ip}") unless dns_find(ip)
      true
    end

    def execute cmd, msg=nil, error_only=false
      tsecs = 5
      response = nil
      interpreter = Proxy::SETTINGS.x86_64 ? 'c:\windows\sysnative\cmd.exe' : 'c:\windows\system32\cmd.exe'
      command  = interpreter + ' /c c:\Windows\System32\dnscmd.exe ' + "#{@server} #{cmd}"

      std_in = std_out = std_err = nil
      begin
        timeout(tsecs) do
          logger.debug "executing: #{command}"
          std_in, std_out, std_err  = Open3.popen3(command)
          response  = std_out.readlines
          response += std_err.readlines
        end
      rescue TimeoutError
        raise Proxy::Dns::Error.new("dnscmd did not respond within #{tsecs} seconds")
      ensure
        std_in.close  unless std_in.nil?
        std_out.close unless std_in.nil?
        std_err.close unless std_in.nil?
      end
      report msg, response, error_only
    end

    def report msg, response, error_only
      if response.grep(/completed successfully/).empty?
        logger.error "Dnscmd failed:\n" + response.join("\n")
        msg.sub! /Removed/,    "remove"
        msg.sub! /Added/,      "add"
        msg  = "Failed to #{msg}"
        raise Proxy::Dns::Error.new(msg)
      else
        logger.info msg unless error_only
      end
    rescue Proxy::Dns::Error
      raise
    rescue
      logger.error "Dnscmd failed:\n" + (response.is_a?(Array) ? response.join("\n") : "Response was not an array! #{response}")
      raise Proxy::Dns::Error.new("Unknown error while processing '#{msg}'")
    end
  end
end
