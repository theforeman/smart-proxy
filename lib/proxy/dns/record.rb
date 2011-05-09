module Proxy::DNS
  class Record
    include Proxy::Log
    include Validations

    def initialize options = {}
      @server = options[:server] || "localhost"
      @fqdn   = options[:fqdn]
      @ttl    = options[:ttl]    || "86400"
      @type   = options[:type]   || "A"
      @value  = options[:value]

      raise("Must define FQDN or Value") if @fqdn.nil? and @value.nil?
    end

    def create value
      raise Proxy::DNS::Error, "not implemented"
    end

    def destroy value
      raise Proxy::DNS::Error, "not implemented"
    end

  end
end
