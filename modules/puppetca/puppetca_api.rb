module Proxy::PuppetCa
  class Api < ::Sinatra::Base
    extend Proxy::PuppetCa::DependencyInjection
    inject_attr :puppetca_impl, :puppetca_impl
    inject_attr :autosigner, :autosigner

    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    get "/?" do
      content_type :json
      begin
        puppetca_impl.list.to_json
      rescue => e
        log_halt 406, "Failed to list certificates: #{e}"
      end
    end

    get "/autosign" do
      content_type :json
      begin
        autosigner.autosign_list.to_json
      rescue => e
        log_halt 406, "Failed to list autosign entries: #{e}"
      end
    end

    post "/autosign/:certname" do
      content_type :json
      certname = params[:certname]
      token_ttl = params[:token_ttl]
      begin
        autosigner.autosign(certname, token_ttl)
      rescue => e
        log_halt 406, "Failed to enable autosign for #{certname}: #{e}"
      end
    end

    post "/validate" do
      content_type :json
      unless autosigner.respond_to?(:validate_csr)
        log_halt 501, "Provider only supports trivial autosigning"
      end
      begin
        request.body.rewind
        autosigner.validate_csr(request.body.read) ? 200 : 404
      rescue => e
        log_halt 406, "Failed to validate CSR: #{e}"
      end
    end

    delete "/autosign/:certname" do
      content_type :json
      certname = params[:certname]
      begin
        autosigner.disable(certname)
      rescue Proxy::PuppetCa::NotPresent => e
        log_halt 404, e.to_s
      rescue => e
        log_halt 406, "Failed to remove autosign for #{certname}: #{e}"
      end
    end

    post "/:certname" do
      content_type :json
      certname = params[:certname]
      begin
        puppetca_impl.sign(certname)
      rescue => e
        log_halt 406, "Failed to sign certificate(s) for #{certname}: #{e}"
      end
    end

    delete "/:certname" do
      begin
        content_type :json
        certname = params[:certname]
        puppetca_impl.clean(certname)
      rescue Proxy::PuppetCa::NotPresent => e
        log_halt 404, e.to_s
      rescue => e
        log_halt 406, "Failed to remove certificate(s) for #{certname}: #{e}"
      end
    end
  end
end
