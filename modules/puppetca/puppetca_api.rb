require 'puppetca/puppetca_main'

module Proxy::PuppetCa
  class Api < ::Sinatra::Base
    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    get "/?" do
      content_type :json
      begin
        Proxy::PuppetCa.list.to_json
      rescue => e
        log_halt 406, "Failed to list certificates: #{e}"
      end
    end

    get "/autosign" do
      content_type :json
      begin
        Proxy::PuppetCa.autosign_list.to_json
      rescue => e
        log_halt 406, "Failed to list autosign entries: #{e}"
      end
    end

    post "/autosign/:certname" do
      content_type :json
      certname = params[:certname]
      begin
        Proxy::PuppetCa.autosign(certname)
      rescue => e
        log_halt 406, "Failed to enable autosign for #{certname}: #{e}"
      end
    end

    delete "/autosign/:certname" do
      content_type :json
      certname = params[:certname]
      begin
        Proxy::PuppetCa.disable(certname)
      rescue Proxy::PuppetCa::NotPresent => e
        log_halt 404, "#{e}"
      rescue => e
        log_halt 406, "Failed to remove autosign for #{certname}: #{e}"
      end
    end

    post "/:certname" do
      content_type :json
      certname = params[:certname]
      begin
        Proxy::PuppetCa.sign(certname)
      rescue => e
        log_halt 406, "Failed to sign certificate(s) for #{certname}: #{e}"
      end
    end

    delete "/:certname" do
      begin
        content_type :json
        certname = params[:certname]
        Proxy::PuppetCa.clean(certname)
      rescue Proxy::PuppetCa::NotPresent => e
        log_halt 404, "#{e}"
      rescue => e
        log_halt 406, "Failed to remove certificate(s) for #{certname}: #{e}"
      end
    end
  end
end
