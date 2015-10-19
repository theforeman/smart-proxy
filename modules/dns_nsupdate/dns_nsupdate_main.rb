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
      do_create(fqdn, ip, "A")
    end

    def create_ptr_record(fqdn, ip)
      do_create(ip, fqdn, "PTR")
    end

    def do_create(id, value, type)
      nsupdate_connect

      if found = dns_find(id)
        raise(Proxy::Dns::Collision, "#{id} is already used by #{found}") unless found == value
      else
        nsupdate "update add #{id}. #{@ttl} #{type} #{value}"
      end

      nsupdate_disconnect
    ensure
      @om.close unless @om.nil? || @om.closed?
    end

    def remove_a_record(fqdn)
      do_remove(fqdn, "A")
    end

    def remove_ptr_record(ip)
      do_remove(ip, "PTR")
    end

    def do_remove(id, type)
      nsupdate_connect

      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{id}") unless dns_find(id)
      nsupdate "update delete #{id} #{type}"

      nsupdate_disconnect
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
      unless File.exist?("#{@nsupdate}")
        logger.warn "unable to find nsupdate binary, maybe missing bind-utils package?"
        raise "unable to find nsupdate binary"
      end
    end
  end
end
