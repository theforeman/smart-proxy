require "proxy/dns"

module Proxy::DNS
  class Bind < Record

    def initialize options = {}
      raise "Unable to find Key file - check your dns_key settings" unless SETTINGS.dns_key == false or File.exists?(SETTINGS.dns_key)
      super(options)
    end

    # create({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    # create({ :fqdn => "node01.lab", :value => "3.100.168.192.in-addr.arpa",
    #          :type => "PTR"}
    def create
      nsupdate "connect"
      case @type
      when "A"
        nsupdate "update add #{@fqdn}.  #{@ttl} #{@type} #{@value}"
      when "PTR"
        nsupdate "update add #{@value}.  #{@ttl} IN #{@type} #{@fqdn}"
      end
      nsupdate "disconnect"
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

    def nsupdate cmd
      status = nil
      if cmd == "connect"
        @om = IO.popen("/usr/bin/nsupdate -k #{SETTINGS.dns_key}", "r+")
        @om.puts "server #{@server}"
      elsif cmd == "disconnect"
        @om.puts "send"
        @om.puts "answer"
        @om.close_write
        status = @om.readlines
        @om.close
        @om = nil # we cannot serialize an IO obejct, even if closed.
        # TODO Parse output for errors!
        if status.empty?
          logger.debug "nsupdate returned no status!"
          false
        elsif status[1] !~ /status: NOERROR/
          logger.debug "nsupdate: errors\n" + status.join("\n")
          false
        else
          true
        end
      else
        logger.debug "nsupdate: executed - #{cmd}"
        @om.puts cmd
      end
    end
  end
end
