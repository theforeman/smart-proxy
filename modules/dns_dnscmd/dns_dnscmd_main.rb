require 'resolv'
require 'open3' if RUBY_PLATFORM =~ /mingw/

module Proxy::Dns::Dnscmd
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util
    attr_reader :resolver

    def self.record(attrs = {})
      new(attrs.merge(:server => ::Proxy::Dns::Dnscmd::Plugin.settings.dns_server,
                      :ttl => ::Proxy::Dns::Plugin.settings.dns_ttl))
    end

    def initialize options = {}
      super(options)
    end

    # create({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    # create({ :fqdn => "node01.lab", :value => "3.100.168.192.in-addr.arpa",
    #          :type => "PTR"}
    def create
      @resolver = Resolv::DNS.new(:nameserver => @server)
      case @type
        when "A"
          if ip = dns_find(@fqdn)
            raise(Proxy::Dns::Collision, "#{@fqdn} is already used by #{ip}") unless ip == @value
          else
            zone = @fqdn.sub(/[^.]+./,'')
            msg = "Added DNS entry #{@fqdn} => #{@value}"
            cmd = "/RecordAdd #{zone} #{@fqdn}. A #{@value}"
            execute(cmd, msg)
          end
        when "PTR"
          if name = dns_find(@value)
            raise(Proxy::Dns::Collision, "#{@value} is already used by #{name}") unless name == @fqdn
          else
            # TODO: determine reverse zone names, #4025
            true
          end
      end
    end

    # remove({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    # remove({ :fqdn => "node01.lab", :value => "3.100.168.192.in-addr.arpa"}
    def remove
      @resolver = Resolv::DNS.new(:nameserver => @server)
      case @type
        when "A"
          raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{@fqdn}") unless dns_find(@fqdn)
          zone = @fqdn.sub(/[^.]+./,'')
          msg = "Removed DNS entry #{@fqdn} => #{@value}"
          cmd = "/RecordDelete #{zone} #{@fqdn}. A /f"
          execute(cmd, msg)
        when "PTR"
          # TODO: determine reverse zone names, #4025
          raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{@value}") unless dns_find(@value)
          true
      end
    end

    private

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
