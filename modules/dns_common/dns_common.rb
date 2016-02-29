require 'resolv'
require 'ipaddr'

module Proxy::Dns
  class Error < RuntimeError; end
  class NotFound < RuntimeError; end
  class Collision < RuntimeError; end

  class Record
    attr_reader :server, :ttl

    def initialize(server = nil, ttl = nil)
      @server = server || "localhost"
      @ttl    = ttl || "86400"
    end

    def resolver
      Resolv::DNS.new(:nameserver => @server)
    end

    def dns_find key
      if match = key.match(/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/)
        resolver.getname(match[1..4].reverse.join(".")).to_s
      else
        resolver.getaddress(key).to_s
      end
    rescue Resolv::ResolvError
      false
    end

    def ptr_to_ip ptr
     if ptr =~ /\.in-addr\.arpa$/
       ptr.split('.')[0..-3].reverse.join('.')
     elsif ptr =~ /\.ip6\.arpa$/
       ptr.split('.')[0..-3].reverse.each_slice(4).inject([]) {|address, word| address << word.join}.join(":")
     else
       raise Proxy::Dns::Error.new("Not a PTR record: '#{ptr}'")
     end
    end

    # conflict methods return values:
    # no conflict: -1; conflict: 1, conflict but record / ip matches: 0
    def a_record_conflicts(fqdn, ip)
      if ip_addr = to_ipaddress(ip)
        addresses = resolver.getaddresses(fqdn).select { |a| a =~ Resolv::IPv4::Regex }
        return -1 if addresses.empty?
        return 0 if addresses.any? {|a| IPAddr.new(a.to_s) == ip_addr}
        1
      else
        raise Proxy::Dns::Error.new("Not an IP Address: '#{ip}'")
      end
    end

    def aaaa_record_conflicts(fqdn, ip)
      if ip_addr = to_ipaddress(ip)
        addresses = resolver.getaddresses(fqdn).select { |a| a =~ Resolv::IPv6::Regex }
        return -1 if addresses.empty?
        return 0 if addresses.any? {|a| IPAddr.new(a.to_s) == ip_addr}
        1
      else
        raise Proxy::Dns::Error.new("Not an IP Address: '#{ip}'")
      end
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
  end
end
