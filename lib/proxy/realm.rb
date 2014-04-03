module Proxy::Realm
  class Error < RuntimeError; end
  class NotFound < Error; end

  class Client
    include Proxy::Log
    include Proxy::Util

  end
end
