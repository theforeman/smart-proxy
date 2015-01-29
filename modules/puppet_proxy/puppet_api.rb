require 'puppet_proxy/environment'

class Proxy::Puppet::Api < ::Sinatra::Base
  helpers ::Proxy::Helpers
  authorize_with_trusted_hosts
  authorize_with_ssl_client

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
      Proxy::Puppet::Environment.all.map(&:name).to_json
    rescue => e
      log_halt 406, "Failed to list puppet environments: #{e}"
    end
  end

  get "/environments/:environment" do
    content_type :json
    begin
      env = Proxy::Puppet::Environment.find(params[:environment])
      log_halt 404, "Not found" unless env
      {:name => env.name, :paths => env.paths}.to_json
    rescue => e
      log_halt 406, "Failed to show puppet environment: #{e}"
    end
  end

  get "/environments/:environment/classes" do
    content_type :json
    begin
      env = Proxy::Puppet::Environment.find(params[:environment])
      log_halt 404, "Not found" unless env
      env.classes.map{|k| {k.to_s => { :name => k.name, :module => k.module, :params => k.params} } }.to_json
    rescue => e
      log_halt 406, "Failed to show puppet classes: #{e}"
    end
  end
end
