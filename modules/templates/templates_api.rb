require 'templates/handler'
class Proxy::TemplatesApi < Sinatra::Base
  helpers ::Proxy::Helpers

  # When template feature is used, foreman uses this end-point to provide basse url for hosts to fetch templates.
  # It will also modify the rendering of the foreman_url specified in the templates.
  get "/templateServer" do
    begin
      content_type :json
      {"templateServer" => (Proxy::Templates::Plugin.settings.template_url || "")}.to_json
    rescue => e
      log_halt 400, e
    end
  end

  get "/:kind" do |kind|
    log_halt(500, "Failed to retrieve #{kind} template for #{params.inspect}: ") do
      Proxy::Templates::Handler.get_template(kind, params)
    end
  end
end
