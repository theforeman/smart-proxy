module Proxy::DNS
  extend Proxy::Log

  class << self

    # create({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    # create({ :fqdn => "node01.lab", :value => "3.100.168.192.in-addr.arpa",
    #          :type => "PTR"}
    def create options = {}
      parse_options(options)
      nsupdate "connect"
      case @type
      when "A"
        nsupdate "update add #{@fqdn}.  #{@ttl} #{@type} #{@value}"
      when "PTR"
        nsupdate "update add #{@value}.  #{@ttl} IN #{@type} #{@fqdn}"
      end
      nsupdate "disconnect"
      true
    end

    # remove({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    def remove options = {}
      parse_options(options)
      nsupdate "connect"
      case @type
      when "A"
        nsupdate "update delete #{@fqdn} #{@type}"
      when "PTR"
        nsupdate "update delete #{@value} #{@type}"
      end
      nsupdate "disconnect"
      true
    end

    private

    def parse_options options = {}
      @server = options[:zone] || "localhost"
      @fqdn = options[:fqdn]
      @ttl  = options[:ttl] || "86400"
      @type = options[:type] || "A"
      @value = options[:value]
    end

    def nsupdate cmd
      status = nil
      if cmd == "connect"
        @om = IO.popen("/usr/bin/nsupdate -k #{SETTINGS[:dns_key]}", "r+")
        @om.puts "server #{@server}"
      elsif
        cmd == "disconnect"
        @om.puts "send"
        @om.puts "answer"
        @om.close_write
        status = @om.readlines
        @om.close
        @om = nil # we cannot serialize an IO obejct, even if closed.
      else
        logger.debug "nsupdate: executed - #{cmd}"
        @om.puts cmd
      end
    end

  end
end
