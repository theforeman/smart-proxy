require "proxy/dns"
require 'mysql'

module Proxy::DNS
  class PowerDNS < Record
    include Proxy::Util

    def initialize options = {}
      @mysql_connection = Mysql.new(SETTINGS.dns_mysql_hostname, SETTINGS.dns_mysql_username, SETTINGS.dns_mysql_password, SETTINGS.dns_mysql_database)
      super(options)
    end

    # create({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    # create({ :fqdn => "node01.lab", :value => "3.100.168.192.in-addr.arpa",
    #          :type => "PTR"}
    def create
      unless domain_id
        raise Proxy::DNS::Error, "Unable to determine zone. Zone must exist in PowerDNS."
      end

      case @type
        when "A"
          if ip = dns_find(@fqdn)
            raise Proxy::DNS::Collision, "#{@fqdn} is already in use by #{ip}"
          else
            @mysql_connection.query("INSERT INTO records (records.domain_id,records.name,records.ttl,records.content,records.type) VALUES (#{id}, '#{@fqdn}', #{@ttl}, '#{@value}', '#{@type}');")
          end
        when "PTR"
          ip = IPAddr.new(@value)
          ptrname = ip.reverse
          if name = dns_find(ptrname)
            raise Proxy::DNS::Collision, "#{@value} is already used by #{name}"
          else
            @mysql_connection.query("INSERT INTO records (records.domain_id,records.name,records.ttl,records.content,records.type) VALUES (#{id}, '#{ptrname}', #{@ttl}, '#{@fqdn}', 'PTR');")
          end
        end
    end

    # remove({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    def remove
      case @type
      when "A"
        @mysql_connection.query("DELETE FROM records WHERE name='#{@fqdn}'")
      when "PTR"
        ip = IPAddr.new(@value)
        ptrname = ip.reverse
        @mysql_connection.query("DELETE FROM records WHERE name='#{ptrname}'")
      end
    end

    private
    def domain_id
      case @type
      when "A"
        host_list = @fqdn.split(/\./);
        search_depth = 1
      when "PTR"
        host_list = @value.split(/\./).reverse;
        search_depth = 0
      end

      id = nil

      while id == nil && host_list.length != search_depth && host_list != nil
        domain = host_list * "."
        if @type == "PTR"
          domain.concat(".in-addr.arpa")
        end
        res = @mysql_connection.query("SELECT id FROM domains WHERE name = '#{domain}' LIMIT 1;")
        if res.num_rows() != 0
          id = res.fetch_row
        end
        res.free
        host_list.delete_at(0)
      end
      id
    end

    private
    def dns_find key
      value = nil
      res = @mysql_connection.query("SELECT content FROM records WHERE name = '#{key}' LIMIT 1;")
      if res.num_rows() != 0
        value = res.fetch_row
      end
      res.free
      if value != nil
        value
      else
        false
      end
    end
  end
end
