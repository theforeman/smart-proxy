module Proxy::Puppet
  class EnvironmentNotFound < StandardError; end
  class NotReady < StandardError; end
  class DataError < StandardError; end
  class TimeoutError < StandardError; end
end
