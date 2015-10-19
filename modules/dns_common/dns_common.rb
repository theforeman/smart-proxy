module Proxy::Dns
  class Error < RuntimeError; end
  class NotFound < RuntimeError; end
  class Collision < RuntimeError; end

  class Record
    attr_reader :server, :ttl

    def initialize(server = nil, ttl = nil)
      @server = server || "localhost"
      @ttl    = ttl || "86400"
    end

    def resolver
      Resolv::DNS.new(:nameserver => @server)
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
