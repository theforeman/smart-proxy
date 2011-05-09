module Proxy::DNS
  class Zone
    include Validations
    attr_reader :name, :records, :server

    def initialize(args)
      @name = validate_zone_name(args[:name])
      @loaded = false
      @server = validate_server(args[:server])
    end

    def clear
      @records = {}
      @loaded  = false
    end

    def loaded?
      @loaded
    end

    def size
      records.size
    end

    def load
      self.clear
      return false if loaded?
      @loaded = true
      server.loadZoneData self
      logger.debug "Lazy loaded #{to_s} records"
    end

    def reload
      clear
      self.load
    end

    def records
      self.load if not loaded?
      @records.values
    end

    def inspect
      self
    end

    def <=> other
      name <=> other.name
    end

  end
end
