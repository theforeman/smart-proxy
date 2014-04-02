require 'realm/realm_plugin'

module Proxy::Realm
  class Error < RuntimeError; end
  class NotFound < Error; end
end
