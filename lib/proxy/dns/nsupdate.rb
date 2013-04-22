require "proxy/dns"
require 'resolv'

module Proxy::DNS
  class Nsupdate < Record

    include Proxy::Util
    attr_reader :resolver

    def initialize options = {}
      raise "Unable to find Key file - check your dns_key settings" unless SETTINGS.dns_key == false or File.exists?(SETTINGS.dns_key)
      if SETTINGS.dns_tsig_keytab
        raise "Kerberos principal required - check dns_tsig_principal setting" unless SETTINGS.dns_tsig_principal
        logger.debug "DNS GSS-TSIG authentication enabled"
        require 'krb5_auth'
      end
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
            raise(Proxy::DNS::Collision, "#{@fqdn} is already used by #{ip}") unless ip == @value
          else
            nsupdate "update add #{@fqdn}.  #{@ttl} #{@type} #{@value}"
          end
        when "PTR"
          if name = dns_find(@value)
            raise(Proxy::DNS::Collision, "#{@value} is already used by #{name}") unless name == @fqdn
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

    def nsupdate_args
      args = ""
      args = "-k #{SETTINGS.dns_key} " if SETTINGS.dns_key
      args += "-g " if SETTINGS.dns_tsig_keytab
      args
    end

    def find_nsupdate
      @nsupdate = which("nsupdate", "/usr/bin")
      unless File.exists?("#{@nsupdate}")
        logger.warn "unable to find nsupdate binary, maybe missing bind-utils package?"
        raise "unable to find nsupdate binary"
      end
    end

    def init_krb5_ccache
      krb5 = Krb5Auth::Krb5.new
      ccache = Krb5Auth::Krb5::CredentialsCache.new
      logger.info "Requesting credentials for Kerberos principal #{SETTINGS.dns_tsig_principal} using keytab #{SETTINGS.dns_tsig_keytab}"
      begin
        krb5.get_init_creds_keytab SETTINGS.dns_tsig_principal, SETTINGS.dns_tsig_keytab, nil, ccache
      rescue => e
        logger.error "Failed to initialise credential cache from keytab: #{e}"
        raise Proxy::DNS::Error.new("Unable to initialise Kerberos: #{e}")
      end
      logger.debug "Kerberos credential cache initialised with principal: #{ccache.primary_principal}"
    end

    def nsupdate cmd
      status = nil
      if cmd == "connect"
        find_nsupdate if @nsupdate.nil?
        init_krb5_ccache if SETTINGS.dns_tsig_keytab
        nsupdate_cmd = "#{@nsupdate} #{nsupdate_args}"
        logger.debug "running #{nsupdate_cmd}"
        @om = IO.popen(nsupdate_cmd, "r+")
        logger.debug "nsupdate: executed - server #{@server}"
        @om.puts "server #{@server}"
      elsif cmd == "disconnect"
        @om.puts "send"
        @om.puts "answer"
        @om.close_write
        status = @om.readlines
        @om.close
        @om = nil # we cannot serialize an IO object, even if closed.
        # TODO Parse output for errors!
        if !status.empty? and status[1] !~ /status: NOERROR/
          logger.debug "nsupdate: errors\n" + status.join("\n")
          raise Proxy::DNS::Error.new("Update errors: #{status.join("\n")}")
        end
      else
        logger.debug "nsupdate: executed - #{cmd}"
        @om.puts cmd
      end
    end

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
