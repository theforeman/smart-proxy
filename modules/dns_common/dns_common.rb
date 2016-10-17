require 'resolv'
require 'ipaddr'

module Proxy::Dns
  class Error < RuntimeError; end
  class NotFound < RuntimeError; end
  class Collision < RuntimeError; end

  class Record
    include ::Proxy::Log

    attr_reader :server, :ttl

    def initialize(server = nil, ttl = nil)
      @server = server || "localhost"
      @ttl    = ttl || "86400"
    end

    def resolver
      Resolv::DNS.new(:nameserver => @server)
    end

    def dns_find(key)
      logger.warn(%q{Proxy::Dns::Record#dns_find has been deprecated and will be removed in future versions of Smart-Proxy.
                      Please use ::Proxy::Dns::Record#get_name or ::Proxy::Dns::Record#get_address instead.})
      if key =~ /\.in-addr\.arpa$/ || key =~ /\.ip6\.arpa$/
        resolver.getname(ptr_to_ip(key)).to_s
      else
        resolver.getaddress(key).to_s
      end
    rescue Resolv::ResolvError
      false
    end

    def get_name(a_ptr)
      resolver.getname(ptr_to_ip(a_ptr))
    rescue Resolv::ResolvError
      false
    end

    def get_name!(a_ptr)
      resolver.getname(ptr_to_ip(a_ptr))
    rescue Resolv::ResolvError
      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{a_ptr}")
    end

    def get_ipv4_address!(fqdn)
      get_address!(fqdn, Resolv::IPv4::Regex)
    end

    def get_ipv4_address(fqdn)
      get_address(fqdn, Resolv::IPv4::Regex)
    end

    def get_ipv6_address!(fqdn)
      get_address!(fqdn, Resolv::IPv6::Regex)
    end

    def get_ipv6_address(fqdn)
      get_address(fqdn, Resolv::IPv6::Regex)
    end

    def get_address(a_fqdn, should_match = nil)
      addresses = getaddresses(a_fqdn)
      found = should_match.nil? ? addresses.first : addresses.find {|a| a =~ should_match}
      found || false
    rescue Resolv::ResolvError
      false
    end

    def get_address!(a_fqdn, should_match = nil)
      found = get_address(a_fqdn, should_match)
      raise Proxy::Dns::NotFound.new("Cannot find DNS entry for #{a_fqdn}") unless found
      found
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
      if ip_addr = to_ipaddress(ip)
        addresses = getaddresses(fqdn).select { |a| a =~ Resolv::IPv4::Regex }
        return -1 if addresses.empty?
        return 0 if addresses.any? {|a| IPAddr.new(a.to_s) == ip_addr}
        1
      else
        raise Proxy::Dns::Error.new("Not an IP Address: '#{ip}'")
      end
    end

    def aaaa_record_conflicts(fqdn, ip)
      if ip_addr = to_ipaddress(ip)
        addresses = getaddresses(fqdn).select { |a| a =~ Resolv::IPv6::Regex }
        return -1 if addresses.empty?
        return 0 if addresses.any? {|a| IPAddr.new(a.to_s) == ip_addr}
        1
      else
        raise Proxy::Dns::Error.new("Not an IP Address: '#{ip}'")
      end
    end

    def cname_record_conflicts(fqdn, target)
      current = resolver.getresources(fqdn, Resolv::DNS::Resource::IN::CNAME)
      return -1 if current.empty?
      return 0 if current[0].name.to_s == target #There can only be one CNAME
      1
    end

    def ptr_record_conflicts(fqdn, ip)
      if ip_addr = to_ipaddress(ip)
        names = resolver.getnames(ip_addr.to_s)
        return -1 if names.empty?
        return 0 if names.any? {|n| n.to_s.casecmp(fqdn) == 0}
        1
      else
        raise Proxy::Dns::Error.new("Not an IP Address: '#{ip}'")
      end
    end

    def to_ipaddress ip
      IPAddr.new(ip) rescue false
    end

    def create_cname_record(fqdn, target)
      raise Proxy::Dns::Error.new("This DNS provider does not support CNAME management")
    end

    def remove_cname_record(fqdn)
      raise Proxy::Dns::Error.new("This DNS provider does not support CNAME management")
    end

    def getaddresses(fqdn)
      resolver.getaddresses(fqdn).map(&:to_s)
    end
  end
end
