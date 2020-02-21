require 'resolv'
require 'ipaddr'
require 'proxy/logging_resolv'

module Proxy::Dns
  class Error < RuntimeError; end
  class NotFound < RuntimeError; end
  class Collision < RuntimeError; end

  class Record
    include ::Proxy::Log
    include ::Proxy::TimeUtils
    include ::Proxy::Helpers

    attr_reader :server, :ttl

    def initialize(server = nil, ttl = nil)
      @server = server || "localhost"
      @ttl = ttl || "86400"
    end

    def resolver(override_nameserver = @server)
      dns_resolv(:nameserver => override_nameserver)
    end

    def create_srv_record(service, value)
      do_create(service, value, 'SRV')
    end

    def create_a_record(fqdn, ip)
      case a_record_conflicts(fqdn, ip) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          nil
        else
          do_create(fqdn, ip, "A")
      end
    end

    def create_aaaa_record(fqdn, ip)
      case aaaa_record_conflicts(fqdn, ip) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          nil
        else
          do_create(fqdn, ip, "AAAA")
      end
    end

    def create_cname_record(fqdn, target)
      case cname_record_conflicts(fqdn, target) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
        when 0 then
          nil
        else
          do_create(fqdn, target, "CNAME")
      end
    end

    def create_ptr_record(fqdn, ptr)
      case ptr_record_conflicts(fqdn, ptr) #returns -1, 0, 1
        when 1 then
          raise(Proxy::Dns::Collision, "'#{ptr}' is already in use")
        when 0
          nil
        else
          do_create(ptr, fqdn, "PTR")
      end
    end

    def do_create(name, value, type)
      raise(Proxy::Dns::Error, "Creation of #{type} not implemented")
    end

    def remove_a_record(fqdn)
      do_remove(fqdn, "A")
    end

    def remove_srv_record(fqdn)
      do_remove(fqdn, 'SRV')
    end

    def remove_aaaa_record(fqdn)
      do_remove(fqdn, "AAAA")
    end

    def remove_cname_record(fqdn)
      do_remove(fqdn, "CNAME")
    end

    def remove_ptr_record(name)
      do_remove(name, "PTR")
    end

    def do_remove(name, type)
      raise(Proxy::Dns::Error, "Deletion of #{type} not implemented")
    end

    def get_name(a_ptr)
      logger.warn('Deprecated: Proxy::Dns::Record#get_name is deprecated and will be removed in 1.24')
      get_resource_as_string(a_ptr, Resolv::DNS::Resource::IN::PTR, :name)
    end

    def get_name!(a_ptr)
      logger.warn('Deprecated: Proxy::Dns::Record#get_name! is deprecated and will be removed in 1.24')
      get_resource_as_string!(a_ptr, Resolv::DNS::Resource::IN::PTR, :name)
    end

    def get_ipv4_address!(fqdn)
      logger.warn('Deprecated: Proxy::Dns::Record#get_ipv4_address! is deprecated and will be removed in 1.24')
      get_resource_as_string!(fqdn, Resolv::DNS::Resource::IN::A, :address)
    end

    def get_ipv4_address(fqdn)
      logger.warn('Deprecated: Proxy::Dns::Record#get_ipv4_address is deprecated and will be removed in 1.24')
      get_resource_as_string(fqdn, Resolv::DNS::Resource::IN::A, :address)
    end

    def get_ipv6_address!(fqdn)
      logger.warn('Deprecated: Proxy::Dns::Record#get_ipv6_address! is deprecated and will be removed in 1.24')
      get_resource_as_string!(fqdn, Resolv::DNS::Resource::IN::AAAA, :address)
    end

    def get_ipv6_address(fqdn)
      logger.warn('Deprecated: Proxy::Dns::Record#get_ipv6_address is deprecated and will be removed in 1.24')
      get_resource_as_string(fqdn, Resolv::DNS::Resource::IN::AAAA, :address)
    end

    def get_resource_as_string(value, resource_type, attr)
      logger.warn('Deprecated: Proxy::Dns::Record#get_resource_as_string is deprecated and will be removed in 1.24')
      resolver.getresource(value, resource_type).send(attr).to_s
    rescue Resolv::ResolvError
      false
    end

    def get_resource_as_string!(value, resource_type, attr)
      logger.warn('Deprecated: Proxy::Dns::Record#get_resource_as_string! is deprecated and will be removed in 1.24')
      resolver.getresource(value, resource_type).send(attr).to_s
    rescue Resolv::ResolvError
      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{value}")
    end

    def ptr_to_ip ptr
     if ptr =~ /\.in-addr\.arpa$/
       ptr.split('.')[0..-3].reverse.join('.')
     elsif ptr =~ /\.ip6\.arpa$/
       ptr.split('.')[0..-3].reverse.each_slice(4).inject([]) {|address, word| address << word.join}.join(":")
     else
       raise Proxy::Dns::Error.new("Not a PTR address: '#{ptr}'")
     end
    end

    # conflict methods return values:
    # no conflict: -1; conflict: 1, conflict but record / ip matches: 0
    def a_record_conflicts(fqdn, ip)
      record_conflicts_ip(fqdn, Resolv::DNS::Resource::IN::A, ip)
    end

    def aaaa_record_conflicts(fqdn, ip)
      record_conflicts_ip(fqdn, Resolv::DNS::Resource::IN::AAAA, ip)
    end

    def cname_record_conflicts(fqdn, target)
      record_conflicts_name(fqdn, Resolv::DNS::Resource::IN::CNAME, target)
    end

    def ptr_record_conflicts(content, name)
      record_conflicts_name(name, Resolv::DNS::Resource::IN::PTR, content)
    end

    def to_ipaddress ip
      logger.warn('Deprecated: Proxy::Dns::Record#to_ipaddress is deprecated and will be removed in 1.24')
      IPAddr.new(ip) rescue false
    end

    private

    def record_conflicts_ip(fqdn, type, ip)
      begin
        ip_addr = IPAddr.new(ip)
      rescue
        raise Proxy::Dns::Error.new("Not an IP Address: '#{ip}'")
      end

      resources = resolver.getresources(fqdn, type)
      return -1 if resources.empty?
      return 0 if resources.any? {|r| IPAddr.new(r.address.to_s) == ip_addr }
      1
    end

    def record_conflicts_name(fqdn, type, content)
      resources = resolver.getresources(fqdn, type)
      return -1 if resources.empty?
      return 0 if resources.any? {|r| r.name.to_s.casecmp(content) == 0 }
      1
    end
  end
end
