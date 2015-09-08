module Proxy::Error
  class BadRequest < StandardError; end
  class Unauthorized < StandardError; end
  class ConfigurationError < StandardError; end
end
