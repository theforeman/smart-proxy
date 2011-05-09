module Proxy::DNS::Validations

  class Error < RuntimeError; end
  private

  def validate_zone_name name
    #TODO: find out conditions for zone names
    raise Error, "Invalid Zone Name #{name}" unless name.is_a?(String)
    name
  end

  def validate_zone zone
    raise Error, "Invalid Zone #{zone}" unless zone.is_A?(Proxy::DNS::Zone)
    zone
  end

  def validate_server server
    raise Error, "Invalid Server #{server}" unless server.is_a?(Proxy::DNS::Server)
    server
  end

  def validate_record record
    raise Error, "Invalid Record #{record}" unless record.is_a?(Proxy::DNS::Record)
    record
  end

end
