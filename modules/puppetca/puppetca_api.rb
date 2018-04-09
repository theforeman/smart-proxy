module Proxy::PuppetCa
  class Api < ::Sinatra::Base
    extend Proxy::PuppetCa::DependencyInjection
    inject_attr :cert_manager, :cert_manager

    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    get "/?" do
      content_type :json
      begin
        cert_manager.list.to_json
      rescue => e
        log_halt 406, "Failed to list certificates: #{e}"
      end
    end

    post "/autosign" do
      request.body.rewind
      begin
        cert_manager.autosign(request.body.read) ? 200 : 404
      rescue => e
        log_halt 406, "Failed to check autosigning for CSR: #{e}"
      end
    end

    post "/:certname" do
      content_type :json
      certname = params[:certname]
      begin
        cert_manager.sign(certname)
      rescue => e
        log_halt 406, "Failed to sign certificate(s) for #{certname}: #{e}"
      end
    end

    delete "/:certname" do
      begin
        content_type :json
        certname = params[:certname]
        cert_manager.clean(certname)
      rescue Proxy::PuppetCa::NotPresent => e
        log_halt 404, e.to_s
      rescue => e
        log_halt 406, "Failed to remove certificate(s) for #{certname}: #{e}"
      end
    end
  end
end
