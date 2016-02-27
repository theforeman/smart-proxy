require 'resolv'
require 'dns_common/dns_common'

module Proxy::Dns::Nsupdate
  class Record < ::Proxy::Dns::Record

    include Proxy::Log
    include Proxy::Util

    def initialize(a_server = nil, a_ttl = nil)
      super(a_server || ::Proxy::Dns::Nsupdate::Plugin.settings.dns_server,
            a_ttl || ::Proxy::Dns::Plugin.settings.dns_ttl)
    end

    def create_a_record(fqdn, ip)
      case a_record_conflicts(fqdn, ip) #returns -1, 0, 1
      when 1
        raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
      when 0 then
        return nil
      else
        do_create(fqdn, ip, "A")
      end
    end

    def create_aaaa_record(fqdn, ip)
      case aaaa_record_conflicts(fqdn, ip) #returns -1, 0, 1
      when 1
        raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
      when 0 then
        return nil
      else
        do_create(fqdn, ip, "AAAA")
      end
    end

    def create_ptr_record(fqdn, ptr)
      case ptr_record_conflicts(fqdn, ptr_to_ip(ptr)) #returns -1, 0, 1
      when 1
        raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
      when 0 then
        return nil
      else
        do_create(ptr, fqdn, "PTR")
      end
    end

    def do_create(id, value, type)
      nsupdate_connect
      nsupdate "update add #{id}. #{@ttl} #{type} #{value}"
      nsupdate_disconnect
      nil
    ensure
      @om.close unless @om.nil? || @om.closed?
    end

    def remove_a_record(fqdn)
      do_remove(fqdn, "A")
    end

    def remove_aaaa_record(fqdn)
      do_remove(fqdn, "AAAA")
    end

    def remove_ptr_record(ip)
      do_remove(ip, "PTR")
    end

    def do_remove(id, type)
      nsupdate_connect

      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{id}") unless dns_find(id)
      nsupdate "update delete #{id} #{type}"

      nsupdate_disconnect
      nil
    end

    def nsupdate_args
      args = ""
      args = "-k #{Proxy::Dns::Nsupdate::Plugin.settings.dns_key} " if Proxy::Dns::Nsupdate::Plugin.settings.dns_key
      args
    end

    def nsupdate_connect
      find_nsupdate if @nsupdate.nil?
      nsupdate_cmd = "#{@nsupdate} #{nsupdate_args}"
      logger.debug "running #{nsupdate_cmd}"
      @om = IO.popen(nsupdate_cmd, "r+")
      logger.debug "nsupdate: executed - server #{@server}"
      @om.puts "server #{@server}"
    end

    def nsupdate_disconnect
      @om.puts "send"
      @om.puts "answer"
      @om.close_write
      status = @om.readlines
      @om.close
      @om = nil # we cannot serialize an IO object, even if closed.
      # TODO Parse output for errors!
      if !status.empty? && status[1] !~ /status: NOERROR/
        logger.debug "nsupdate: errors\n" + status.join("\n")
        raise Proxy::Dns::Error.new("Update errors: #{status.join("\n")}")
      end
    end

    def nsupdate cmd
      logger.debug "nsupdate: executed - #{cmd}"
      @om.puts cmd
    end

    def find_nsupdate
      @nsupdate = which("nsupdate")
      unless File.exist?(@nsupdate.to_s)
        logger.warn "unable to find nsupdate binary, maybe missing bind-utils package?"
        raise "unable to find nsupdate binary"
      end
    end
  end
end
