require 'proxy/template'

class SmartProxy

  # Get the value for templates
  get "/unattended/templateServer" do
     {"templateServer" => (SETTINGS.template_url || "")}.to_json
  end

  # Render a template from Foreman
  get "/unattended/:kind" do |kind|
    log_halt 403, "Proxy not configured to handle templates" unless SETTINGS.templates
    log_halt 403, "No URI specified for :foreman_url:" unless SETTINGS.foreman_url
    log_halt(404, "Failed to retrieve #{kind} template for #{params[:token]}: ") {
      Proxy::Template::Handler.get_template(kind, params[:token])
    }
  end

end
