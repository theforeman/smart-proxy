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
      id = _get_domain_id
      if ! id
        raise(Proxy::DNS::Error, "Unable to determine zone. Zone must exist in PowerDNS.")
      end

      case @type
        when "A"
          if ip = dns_find(@fqdn)
            raise(Proxy::DNS::Collision, "#{@fqdn} is already in use by #{ip}")
          else
            @mysql_connection.query("INSERT INTO records (records.domain_id,records.name,records.ttl,records.content) VALUES (#{id}, '#{@fqdn}', #{@ttl}, '#{@value}');")
          end
        when "PTR"
          _ptrname = @value.split(/\./).reverse * ".";
          _ptrname.concat(".in-addr.arpa")
          if name = dns_find(_ptrname)
            raise(Proxy::DNS::Collision, "#{@value} is already used by #{name}")
          else
            @mysql_connection.query("INSERT INTO records (records.domain_id,records.name,records.ttl,records.content) VALUES (#{id}, '#{_ptrname}', #{@ttl}, '#{@fqdn}');")
          end
        end
    end

    # remove({ :fqdn => "node01.lab", :value => "192.168.100.2"}
    def remove
      case @type
      when "A"
        @mysql_connection.query("DELETE FROM records WHERE name='#{@fqdn}'")
      when "PTR"
        _ptrname = @value.split(/\./).reverse * ".";
        _ptrname.concat(".in-addr.arpa")
        @mysql_connection.query("DELETE FROM records WHERE name='#{_ptrname}'")
      end
    end

    private
    def _get_domain_id
      case @type
      when "A"
        @_hostArray = @fqdn.split(/\./);
        _search_depth = 1
      when "PTR"
        @_hostArray = @value.split(/\./).reverse;
        _search_depth = 0
      end

      _domain_id = nil

      while _domain_id == nil && @_hostArray.length != _search_depth && @_hostArray != nil
        _domain = @_hostArray * "."
        if @type == "PTR"
          _domain.concat(".in-addr.arpa")
        end
        _res = @mysql_connection.query("SELECT id FROM domains WHERE name = '#{_domain}' LIMIT 1;")
        if _res.num_rows() != 0
          _domain_id = _res.fetch_row
        end
        _res.free
        @_hostArray.delete_at(0)
      end
      _domain_id
    end

    private
    def dns_find _key
      _value = nil
      _res = @mysql_connection.query("SELECT content FROM records WHERE name = '#{_key}' LIMIT 1;")
      if _res.num_rows() != 0
        _value = _res.fetch_row
      end
      _res.free
      if _value != nil
        _value
      else
        false
      end
    end
  end
end
