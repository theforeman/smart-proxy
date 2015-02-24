require 'resolv'
require 'route53'

module Proxy::Dns
  class Aws < Record
    include Proxy::Util
    attr_reader :resolver

    def initialize options = {}
      @dns_aws_accesskey = options[:dns_aws_accesskey]
      @dns_aws_secretkey = options[:dns_aws_secretkey]
      raise "Route53: dns_aws_secretkey and dns_aws_accesskey must be set." unless defined? @dns_aws_accesskey and defined? @dns_aws_secretkey
      super(options)
    end

    def create

      conn = Route53::Connection.new(@dns_aws_accesskey , @dns_aws_secretkey)
      @resolver = Resolv::DNS.new
      case @type
        when "A"
          domain = @fqdn.split('.', 2).last + '.'
          zone = conn.get_zones(name=domain)[0]

          if ip = dns_find(@fqdn)
            raise(Proxy::DNS::Collision, "#{@fqdn} is already used by #{ip}") unless ip == @value
          else
            new_record = Route53::DNSRecord.new(@fqdn, 'A', @ttl, [@value], zone)
            resp = new_record.create
            raise "AWS Response Error: #{resp}" if resp.error?
          end
        when "PTR"
          domain = @value.split('.', 2).last + '.'
          zone = conn.get_zones(name=domain)[0]
          if name == dns_find(@value)
            raise(Proxy::DNS::Collision, "#{@value} is already used by #{name}") unless name == @fqdn
          else
            new_record = Route53::DNSRecord.new(@value, 'PTR', @ttl, [@fqdn], zone)
            resp = new_record.create
            raise "AWS Response Error: #{resp}" if resp.error?
          end
      end
    end

    def remove

      conn = Route53::Connection.new(@dns_aws_accesskey, @dns_aws_secretkey)
      case @type
        when "A"
          domain = @fqdn.split('.', 2).last + '.'
          zone = conn.get_zones(name=domain)[0]
          recordset = zone.get_records
          recordset.each do |rec|
            if rec.name == @fqdn + '.'
              resp = rec.delete
              raise "AWS Response Error: #{resp}" if resp.error?
              return
            end
          end
        when "PTR"
          domain = @value.split('.', 2).last + '.'
          zone = conn.get_zones(name=domain)[0]
          recordset = zone.get_records
          recordset.each do |rec|
            if rec.name == @value + '.'
              resp = rec.delete
              raise "AWS Response Error: #{resp}" if resp.error?
              return
            end
          end
      end
    end

    private
    def dns_find key
      puts key
      if match = key.match(/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/)
        resolver.getname(match[1..4].reverse.join(".")).to_s
      else
        resolver.getaddress(key).to_s
      end
    rescue Resolv::ResolvError
      false
    end
  end
end
