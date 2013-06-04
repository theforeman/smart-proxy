require 'pry-remote'
class SmartProxy < Sinatra::Base

  use Rack::MethodOverride
  def client_setup fqdn
    raise "Smart Proxy is not configured to support Realm" unless SETTINGS.realm
    #raise "No client host specified" unless fqdn

    case SETTINGS.realm_vendor.downcase
      when "ipa"

        require 'proxy/realm/ipa'
        unless SETTINGS.realm_tsig_keytab and SETTINGS.realm_tsig_principal \
          and File.exist?(SETTINGS.realm_tsig_keytab)
          log_halt 400, "Unable to find the Realm keytab file (or realm_tsig_principal is not set)"
        end
        Proxy::Realm::IPA.new(
          :fqdn => fqdn,
          #:fqdn => "utest.collmedia.net",
          :tsig_keytab => SETTINGS.realm_tsig_keytab,
          :tsig_principal => SETTINGS.realm_tsig_principal
        )
      else
        log_halt 400, "Unrecognized or missing Realm vendor type: #{SETTINGS.realm_vendor.nil? ? "MISSING" : SETTINGS.realm_vendor}"
    end
  rescue => e
    log_halt 400, e
  end

  helpers do
  end

  before do
    #client_setup params[:fqdn] if request.path_info =~ /realm/
  end

  get "/realm/:fqdn" do
    #fqdn = params[:fqdn]
    #binding.remote_pry

    client = client_setup params[:fqdn]
    
#    binding.remote_pry

    begin
    client.host_find
      if request.accept? 'application/json'
        content_type :json
        {
          :fqdn => client.fqdn,
          :output => client.output,
          #:tsig_keytab => @client.tsig_keytab,
          #:tsig_principal => @client.tsig_principal
        }.to_json
      else
        erb :"realm/show"
      end
    rescue => e
      log_halt 400, e
    end
  end

  # create a new host in a realm
  post "/realm/" do
    fqdn = params[:fqdn]
#    binding.remote_pry
    begin
      client = client_setup fqdn
      client.host_add
      client.pwd.to_json
    rescue Proxy::Realm::Error => e
      log_halt 409, e
    rescue Exception => e
      log_halt 400, e
    end
  end

  # delete a host from a realm
  delete "/realm/:value" do
    fqdn = params[:value]
    begin
      client = client_setup({:fqdn => fqdn})
      client.host_del
    rescue => e
      log_halt 400, e
    end
  end

end

# vim: ai ts=2 sts=2 et sw=2 ft=ruby
