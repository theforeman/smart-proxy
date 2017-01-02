module Proxy::FreeIPARealm
  class IpaConfigParser
    include Proxy::Log

    attr_reader :config_file

    def initialize(config_file)
      @config_file = config_file
    end

    def uri
      return @uri.to_s if @uri
      @uri, @realm = parse_config_file(config_file)
      @uri.to_s
    end

    def host
      return @uri.host if @uri
      @uri, @realm = parse_config_file(config_file)
      @uri.host
    end

    def scheme
      return @uri.scheme if @uri
      @uri, @realm = parse_config_file(config_file)
      @uri.scheme
    end

    def realm
      return @realm if @realm
      @uri, @realm = parse_config_file(config_file)
      @realm
    end

    def parse_config_file(path)
      File.open(path, 'r') { |f| do_parse(f) }
    end

    def do_parse(io)
      parsed_uri, realm_name = nil

      io.readlines.each do |line|
        if line =~ /xmlrpc_uri/
          uri = line.split("=")[1].strip
          parsed_uri = URI.parse(uri)
          logger.debug "freeipa: uri is #{uri}"
        elsif line =~ /realm/
          realm_name = line.split("=")[1].strip
          logger.debug "freeipa: realm #{realm_name}"
        end
      end
      raise Exception.new("unable to parse client configuration") unless parsed_uri && realm_name
      [parsed_uri, realm_name]
    end
  end
end
