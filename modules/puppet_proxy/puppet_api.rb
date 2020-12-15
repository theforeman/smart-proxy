class Proxy::Puppet::Api < ::Sinatra::Base
  extend Proxy::Puppet::DependencyInjection
  helpers ::Proxy::Helpers

  inject_attr :class_retriever_impl, :class_retriever
  inject_attr :environment_retriever_impl, :environment_retriever

  post "/run" do
    log_halt 501, "Puppetrun support has been removed in version 2.3"
  end

  get "/environments" do
    content_type :json
    begin
      environment_retriever.all.map(&:name).to_json
    rescue => e
      log_halt 406, "Failed to list puppet environments: #{e}" # FIXME: replace 406 with status codes from http response
    end
  end

  get "/environments/:environment" do
    content_type :json
    begin
      env = environment_retriever.get(params[:environment])
      {:name => env.name, :paths => env.paths}.to_json
    rescue Proxy::Puppet::EnvironmentNotFound
      log_halt 404, "Could not find environment '#{params[:environment]}'"
    rescue => e
      log_halt 406, "Failed to show puppet environment: #{e}" # FIXME: replace 406 with appropriate status codes
    end
  end

  get "/environments/:environment/classes" do
    content_type :json
    begin
      class_retriever.classes_in_environment(params[:environment]).map { |k| {k.to_s => { :name => k.name, :module => k.module, :params => k.params} } }.to_json
    rescue Proxy::Puppet::EnvironmentNotFound
      log_halt 404, "Could not find environment '#{params[:environment]}'"
    rescue Proxy::Puppet::TimeoutError => e
      log_halt 503, e.message
    rescue Exception => e
      log_halt 406, "Failed to show puppet classes: #{e}"
    end
  end

  get "/environments/:environment/classes_and_errors" do
    content_type :json
    begin
      class_retriever.classes_and_errors_in_environment(params[:environment]).to_json
    rescue NoMethodError
      log_halt 501, "classes_and_errors api end-point is not available for '#{class_retriever.class}' provider"
    rescue Proxy::Puppet::EnvironmentNotFound
      log_halt 404, "Could not find environment '#{params[:environment]}'"
    rescue Proxy::Puppet::TimeoutError => e
      log_halt 503, e.message
    rescue Exception => e
      log_halt 406, "Failed to show puppet classes: #{e}"
    end
  end
end
