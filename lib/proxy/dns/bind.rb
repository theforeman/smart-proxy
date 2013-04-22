require "proxy/dns"
require 'resolv'
require 'date'

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
      if SETTINGS.dns_tsig_keytab
        args += "-g "
        logger.debug "DNS TSIG authentication enabled."
      end
      args
    end

    def kinit_args
      args = ""
      if SETTINGS.dns_tsig_keytab
        args += "-F -k -t #{SETTINGS.dns_tsig_keytab} #{SETTINGS.dns_tsig_principal}"
        logger.debug "kinit #{args}."
      end
      args
    end

    def find_nsupdate
      @nsupdate = which("nsupdate", "/usr/bin")
      unless File.exists?("#{@nsupdate}")
        logger.warn "unable to find nsupdate binary, maybe missing bind-utils package?"
        raise "unable to find nsupdate binary"
      end
    end

    def find_kinit
      @kinit = which("kinit", "/usr/bin")
      unless File.exists?("#{@kinit}")
        logger.warn "unable to find kinit binary, maybe missing krb5-user package?"
        raise "unable to find kinit binary"
      end
    end

    def find_krb5tgt
      krb5tgt = system("klist | grep -i #{SETTINGS.dns_tsig_principal} 2>&1")
      if krb5tgt == false
        exp = 1
        now = 0
        @loggermsg = "unable to find kerberos ticket. Trying to aquire a valid TGT..."
        @raisemsg = "unable to find kerberos ticket. Trying to aquire a valid TGT..."
        kinit
      else
        format = "%d/%m/%y %H:%M"
        krbexp = `klist | grep A.SPACE.CORP | grep '/' | awk -F ' ' '{print $3,$4}'`
        exp = DateTime.strptime(krbexp, format)
        now = DateTime.now
      end
      if now > exp
        logger.warn @logger_msg
        kinit
        raise @raise_msg
      else
        logger.warn "Kerberos ticket still valid. Not aquiring new ticket."
      end
    end

    def kinit
      status = nil
      find_kinit if @kinit.nil?
      om = IO.popen("#{@kinit} #{kinit_args}", "r+")
      om.close_write
      status = om.readlines
      om.close
      om = nil # we cannot serialize an IO object, even if closed.
      # TODO Parse output for errors!
      if !status.empty? and status[1] !~ /status: NOERROR/
        logger.debug "kinit: errors\n" + status.join("\n")
        raise Proxy::DNS::Error.new("Update errors: #{status.join("\n")}")
      end
    end

    def nsupdate cmd
      status = nil
      if cmd == "connect"
        find_nsupdate if @nsupdate.nil?
        if SETTINGS.dns_tsig_keytab
          find_krb5tgt
        end
        @om = IO.popen("#{@nsupdate} #{nsupdate_args}", "r+")
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
