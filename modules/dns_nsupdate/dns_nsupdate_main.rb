require 'resolv'

module Proxy::Dns::Nsupdate
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util

    attr_reader :dns_key

    def initialize(a_server, a_ttl, dns_key)
      @dns_key = dns_key
      super(a_server, a_ttl)
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
      nsupdate_close
    end

    def remove_a_record(fqdn)
      get_ipv4_address!(fqdn)
      do_remove(fqdn, "A")
    end

    def remove_aaaa_record(fqdn)
      get_ipv6_address!(fqdn)
      do_remove(fqdn, "AAAA")
    end

    def remove_ptr_record(ip)
      get_name!(ip)
      do_remove(ip, "PTR")
    end

    def do_remove(id, type)
      nsupdate_connect
      nsupdate "update delete #{id} #{type}"
      nsupdate_disconnect
      nil
    ensure
      nsupdate_close
    end

    def nsupdate_args
      dns_key.nil? ? '' : "-k #{dns_key} "
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

    def nsupdate_close
      @om.close unless @om.nil? || @om.closed?
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
