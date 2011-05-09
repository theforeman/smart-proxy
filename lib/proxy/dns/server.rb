module Proxy::DNS
  # represents a DNS Server
  class Server
    attr_reader :name
    alias_method :to_s, :name

    include Proxy::Log
    include Validations

    def initialize(name)
      @name    = name
      @zones = []
      @loaded  = false
    end

    def loaded?
      @loaded
    end

    def clear
      @zones = []
      @loaded  = false
    end

    def load
      self.clear
      @loaded = true
      loadZones
    end

    def zones
      self.load if not loaded?
      @zones
    end

    # Abstracted Zone loader method
    def loadZones
      logger.debug "Loading zones for #{name}"
    end

    # Abstracted Zone data loader method
    def loadZoneData zone
      raise "Invalid Zone" unless zone.is_a? Proxy::DNS::Zone
      logger.debug "Loading zone data for #{zone}"
    end

    # Abstracted Zone options loader method
    def loadZoneOptions zone
      logger.debug "Loading Zone options for #{zone}"
    end

    # Adds a Zone to a server object
    def add_zone zone
      if find_zone(zone.name).nil?
        @zones << validate_zone(zone)
        logger.debug "Added #{zone} to #{name}"
        return true
      end
      logger.warn "Zone #{zone} already exists in server #{name}"
      return false
    end

    def find_zone value
      zones.each do |z|
        return z if value.is_a?(String) and z.name == value
        return z if value.is_a?(Proxy::DNS::Record) and z.include?(value)
      end
      return nil
    end

    def find_record record
      zones.each do |z|
        z.records.each do |v|
          return v if record.is_a?(String) and (v.name == record)
          return v if record.is_a?(Proxy::DNS::Record) and v == record
        end
      end
      return nil
    end

    def inspect
      self
    end

    def addRecord options = {}
    end

    def delRecord zone, record
      zone.delete record
    end

  end
end
