module Proxy::DNS
  class Server
    include Proxy::Log

    def initalize options = {}
      @server = options[:zone]  || "localhost"
      @fqdn   = options[:fqdn]
      @ttl    = options[:ttl]   || "86400"
      @type   = options[:type]  || "A"
      @value  = options[:value]

      raise("Must define FQDN or Value") if @fqdn.nil? and @value.nil?
    end

  end
end
