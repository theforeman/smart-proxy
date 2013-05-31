require 'rkerberos'
require 'krb5_auth'

module Proxy::Realm
  class Error < RuntimeError; end
  class KerberosError < RuntimeError; end

  class Client
    include Proxy::Log

    def initialize options = {}
      @fqdn   = options[:fqdn]

      raise("Must define FQDN") if @fqdn.nil?
    end

  end
end

# vim: ai ts=2 sts=2 et sw=2 ft=ruby
