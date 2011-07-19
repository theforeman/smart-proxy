require "proxy/dns"
require 'resolv'

module Proxy::DNS
  class Bind < Record

    include Proxy::Util
    attr_reader :resolver

    def initialize options = {}
      raise "Unable to find Key file - check your dns_key settings" unless SETTINGS.dns_key == false or File.exists?(SETTINGS.dns_key)
      super(options)
    end

    # create({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    # create({ :fqdn => "node01.lab", :value => "3.100.168.192.in-addr.arpa",
    #          :type => "PTR"}
    def create
      nsupdate "connect"

      @resolver = Resolv::DNS.new(:nameserver => @server)
      case @type
        when "A"
          if ip = dns_find(@fqdn)
            raise(Proxy::DNS::Collision, "#{@fqdn} is already used by #{ip}")
          else
            nsupdate "update add #{@fqdn}.  #{@ttl} #{@type} #{@value}"
          end
        when "PTR"
          if name = dns_find(@value)
            raise(Proxy::DNS::Collision, "#{@value} is already used by #{name}")
          else
            nsupdate "update add #{@value}.  #{@ttl} IN #{@type} #{@fqdn}"
          end
      end
      nsupdate "disconnect"
    ensure
      @om.close unless @om.nil? or @om.closed?
    end

    # remove({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    def remove
      nsupdate "connect"
      case @type
      when "A"
        nsupdate "update delete #{@fqdn} #{@type}"
      when "PTR"
        nsupdate "update delete #{@value} #{@type}"
      end
      nsupdate "disconnect"
    end

    private

    def find_nsupdate
      @nsupdate = which("nsupdate", "/usr/bin")
      unless File.exists?("#{@nsupdate}")
        logger.warn "unable to find nsupdate binary, maybe missing bind-utils package?"
        raise "unable to find nsupdate binary"
      end
    end

    def nsupdate cmd
      status = nil
      if cmd == "connect"
        find_nsupdate if @nsupdate.nil?
        @om = IO.popen("#{@nsupdate} #{SETTINGS.dns_key ? "-k " + SETTINGS.dns_key : ""}", "r+")
        @om.puts "server #{@server}"
      elsif cmd == "disconnect"
        @om.puts "send"
        @om.puts "answer"
        @om.close_write
        status = @om.readlines
        @om.close
        @om = nil # we cannot serialize an IO object, even if closed.
        # TODO Parse output for errors!
        if status.empty?
          logger.debug "nsupdate returned no status!"
          raise Proxy::DNS::Error.new("Got no response from the DNS server")
        elsif status[1] !~ /status: NOERROR/
          logger.debug "nsupdate: errors\n" + status.join("\n")
          raise Proxy::DNS::Error.new("Update errors: #{status.join("\n")}")
        end
      else
        logger.debug "nsupdate: executed - #{cmd}"
        @om.puts cmd
      end
    end
    private
    def dns_find key
      if match = key.match(/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/)
        resolver.getname(match[1..4].reverse.join(".")).to_s
      else
        resolver.getaddress(key).to_s
      end
    rescue Resolv::ResolvError
      false
    end
  end
end
