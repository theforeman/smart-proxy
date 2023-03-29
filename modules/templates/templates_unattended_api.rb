require 'templates/template_proxy_request'

class Proxy::TemplatesUnattendedApi < Sinatra::Base
  helpers ::Proxy::Helpers

  # When template feature is used, foreman uses this end-point to provide basse url for hosts to fetch templates.
  # It will also modify the rendering of the foreman_url specified in the templates.
  get "/templateServer" do
    content_type :json
    {"templateServer" => (Proxy::Templates::Plugin.settings.template_url || "")}.to_json
  rescue => e
    log_halt 400, e
  end

  get "/:kind/:template/:hostgroup" do |kind, template, hostgroup|
    log_halt(nil, "Failed to retrieve #{kind} hostgroup template for #{params.inspect}: ") do
      Proxy::Templates::TemplateProxyRequest.new.get([kind, template, hostgroup], request.env, params)
    end
  end

  get "/:kind" do |kind|
    log_halt(nil, "Failed to proxy /#{kind} for #{params.inspect}: ") do
      Proxy::Templates::TemplateProxyRequest.new.get([kind], request.env, params)
    end
  end

  post "/:kind" do |kind|
    log_halt(nil, "Failed to proxy /#{kind} for #{params.inspect}: ") do
      params["Content-Type"] = "text/plain"
      Proxy::Templates::TemplateProxyRequest.new.post([kind], request.env, params, request.body.read)
    end
  end
end
