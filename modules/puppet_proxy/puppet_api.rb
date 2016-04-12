class Proxy::Puppet::Api < ::Sinatra::Base
  extend Proxy::Puppet::DependencyInjection::Injectors
  helpers ::Proxy::Helpers

  authorize_with_trusted_hosts
  authorize_with_ssl_client

  inject_attr :class_retriever_impl, :class_retriever
  inject_attr :environment_retriever_impl, :environment_retriever

  def puppet_setup(opts = {})
    raise "Smart Proxy is not configured to support Puppet runs" unless Proxy::Puppet::Plugin.settings.enabled
    case Proxy::Puppet::Plugin.settings.puppet_provider
    when "puppetrun"
      require 'puppet_proxy/puppetrun'
      @server = Proxy::Puppet::PuppetRun.new(opts)
    when "mcollective"
      require 'puppet_proxy/mcollective'
      @server = Proxy::Puppet::MCollective.new(opts)
    when "puppetssh"
      require 'puppet_proxy/puppet_ssh'
      @server = Proxy::Puppet::PuppetSSH.new(opts)
    when "salt"
      require 'puppet_proxy/salt'
      @server = Proxy::Puppet::Salt.new(opts)
    when "customrun"
      require 'puppet_proxy/customrun'
      @server = Proxy::Puppet::CustomRun.new(opts)
    else
      log_halt 400, "Unrecognized or missing puppet_provider: #{Proxy::Puppet::Plugin.settings.puppet_provider || "MISSING"}"
    end
  rescue => e
    log_halt 400, e
  end

  post "/run" do
    nodes = params[:nodes]
    begin
      log_halt 400, "Failed puppet run: No nodes defined" unless nodes
      log_halt 500, "Failed puppet run: Check Log files" unless puppet_setup(:nodes => [nodes].flatten).run
    rescue => e
      log_halt 500, "Failed puppet run: #{e}"
    end
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
    rescue  Proxy::Puppet::EnvironmentNotFound
      log_halt 404, "Could not find environment '#{params[:environment]}'"
    rescue => e
      log_halt 406, "Failed to show puppet environment: #{e}" # FIXME: replace 406 with appropriate status codes
    end
  end

  get "/environments/:environment/classes" do
    content_type :json
    begin
      class_retriever.classes_in_environment(params[:environment]).map{|k| {k.to_s => { :name => k.name, :module => k.module, :params => k.params} } }.to_json
    rescue  Proxy::Puppet::EnvironmentNotFound
      log_halt 404, "Could not find environment '#{params[:environment]}'"
    rescue Exception => e
      log_halt 406, "Failed to show puppet classes: #{e}"
    end
  end
end
