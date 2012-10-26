
class SmartProxy
  def dns_setup(opts)
    case SETTINGS.dns_vendor.downcase
    when "bind"
      require "proxy/dns/bind"
      @server = Proxy::DNS::Bind.new(opts.merge(:server => SETTINGS.dns_server))
    when "powerdns"
      require "proxy/dns/powerdns"
      unless SETTINGS.dns_mysql_database and SETTINGS.dns_mysql_hostname \
        and SETTINGS.dns_mysql_username and SETTINGS.dns_mysql_password
        log_halt 400, "Missing required DNS mysql settings, please ensure proper configuration"
      end
      options = opts.merge({
        :mysql_database => SETTINGS.dns_mysql_database,
        :mysql_hostname => SETTINGS.dns_mysql_hostname,
        :mysql_username => SETTINGS.dns_mysql_username,
        :mysql_password => SETTINGS.dns_mysql_password,
      })
      @server = Proxy::DNS::PowerDNS.new(options)
    else
      log_halt 400, "Unrecognized or missing DNS vendor type: #{SETTINGS.dns_vendor.nil? ? "MISSING" : SETTINGS.dns_vendor}"
    end
  end

  before '/dns/*' do
    case request.request_method
    when 'DELETE'
      case params[:value]
      when /\.(in-addr|ip6)\.arpa$/
        type = "PTR"
        value = params[:value]
      else
        fqdn = params[:value]
      end
    else
      fqdn  = params[:fqdn]
      value = params[:value]
      type  = params[:type]
    end
    dns_setup({:fqdn => fqdn, :value => value, :type => type})
  end

  post "/dns/" do
    begin
      @server.create
    rescue Proxy::DNS::Collision => e
      log_halt 409, e
    rescue Exception => e
      log_halt 400, e
    end
  end

  delete "/dns/:value" do
    begin
      @server.remove
    rescue Exception => e
      log_halt 400, e
    end
  end
end
