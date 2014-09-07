require 'proxy/request'
require 'chef_proxy/authentication'
require 'chef_proxy/resources/node'
require 'chef_proxy/resources/client'

module Proxy::Chef
  class Api < ::Sinatra::Base
    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts

    error Proxy::Error::BadRequest do
      log_halt(400, "Bad request : " + env['sinatra.error'].message )
    end

    error Proxy::Error::Unauthorized do
      log_halt(401, "Unauthorized : " + env['sinatra.error'].message )
    end

    post "/hosts/facts" do
      logger.debug 'facts upload request received'
      Proxy::Chef::Authentication.new.authenticated(request) do |content|
        Proxy::HttpRequest::Facts.new.post_facts(content)
      end
    end

    post "/reports" do
      logger.debug 'report upload request received'
      Proxy::Chef::Authentication.new.authenticated(request) do |content|
        Proxy::HttpRequest::Reports.new.post_report(content)
      end
    end

    get "/chefproxy/nodes/:fqdn" do
      logger.debug "Showing node #{params[:fqdn]}"

      content_type :json
      if (node = Proxy::Chef::Resources::Node.new.show(params[:fqdn]))
        node.to_json
      else
        log_halt 404, "Node #{params[:fqdn]} not found"
      end
    end

    get "/chefproxy/clients/:fqdn" do
      logger.debug "Showing client #{params[:fqdn]}"

      content_type :json
      if (node = Proxy::Chef::Resources::Client.new.show(params[:fqdn]))
        node.to_json
      else
        log_halt 404, "Client #{params[:fqdn]} not found"
      end
    end

    delete "/chefproxy/nodes/:fqdn" do
      logger.debug "Starting deletion of node #{params[:fqdn]}"

      result = Proxy::Chef::Resources::Node.new.delete(params[:fqdn])
      log_halt 400, "Node #{params[:fqdn]} could not be deleteded" unless result

      logger.debug "Node #{params[:fqdn]} deleted"
      { :result => result }.to_json
    end

    delete "/chefproxy/clients/:fqdn" do
      logger.debug "Starting deletion of client #{params[:fqdn]}"

      result = Proxy::Chef::Resources::Client.new.delete(params[:fqdn])
      log_halt 400, "Client #{params[:fqdn]} could not be deleted" unless result

      logger.debug "Client #{params[:fqdn]} deleted"
      { :result => result }.to_json
    end
  end
end
