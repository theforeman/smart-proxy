module Proxy::BMC
  class Api < ::Sinatra::Base
    helpers ::Proxy::Helpers
    authorize_with_trusted_hosts
    authorize_with_ssl_client

    # All GET requests will only read ipmi data, no changes
    # All PUT requests will update information on the bmc device

    # FIXME: this is broken... 
    get "" do
      # return list of available options
    end

    # FIXME: this is broken... Returns a list of bmc providers
    get "/providers" do
      { :providers => Proxy::BMC.providers }.to_json
    end

    # FIXME: this is broken... Returns a list of installed providers
    get "/providers/installed" do
      { :installed_providers => Proxy::BMC.installed_providers? }.to_json
    end

    # returns host operations
    get "/:host" do
      { :actions => %w[chassis lan test] }.to_json
    end

    # runs a test against the bmc device and returns true if the connection was successful
    get "/:host/test" do
      bmc_setup
      begin
        result = @bmc.test
        { :action => :test, :result => result }.to_json
      rescue => e
        log_halt 400, e
      end
    end

    # returns chassis operations
    get "/:host/chassis" do
      { :actions => %w[power identify config] }.to_json
    end

    # Gets the power status, does not change power
    get "/:host/chassis/power/?:action?" do
      # return hint on valid options
      if params[:action].nil?
        return { :actions => ["on", "off", "status"] }.to_json
      end
      bmc_setup
      begin
        case params[:action]
          when "status"
            { :action => params[:action], :result => @bmc.powerstatus }.to_json
          when "off"
            { :action => params[:action], :result => @bmc.poweroff? }.to_json
          when "on"
            { :action => params[:action], :result => @bmc.poweron? }.to_json
          else
            { :error => "The action: #{params[:action]} is not a valid action" }.to_json
        end
      rescue => e
        log_halt 400, e
      end
    end

    get "/:host/lan/?:action?" do
      if params[:action].nil?
        return { :actions => ["ip", "netmask", "mac", "gateway"] }.to_json
      end
      bmc_setup
      begin
        case params[:action]
          when "ip"
            { :action => params[:action], :result => @bmc.ip }.to_json
          when "netmask"
            { :action => params[:action], :result => @bmc.netmask }.to_json
          when "mac"
            { :action => params[:action], :result => @bmc.mac }.to_json
          when "gateway"
            { :action => params[:action], :result => @bmc.gateway }.to_json
          else
            { :error => "The action: #{params[:action]} is not a valid action" }.to_json
        end
      rescue => e
        log_halt 400, e
      end
    end

    get "/:host/chassis/identify/?:action?" do
      # return hint on valid options
      if params[:action].nil?
        return { :actions => ["status"] }.to_json
      end
      bmc_setup
      # determine which function should be executed
      begin
        case params[:action]
          when "status"
            { :action => params[:action], :result => @bmc.identifystatus }.to_json
          else
            { :error => "The action: #{params[:action]} is not a valid action" }.to_json
        end
      rescue => e
        log_halt 400, e
      end
    end

    get "/:host/chassis/config/?:function?" do
      # return hint on valid options
      # removing bootdevice until its supported in rubyipmi
      if params[:function].nil?
        #return {:actions => ["bootdevice", "bootdevices"]}.to_json
        return { :functions => ["bootdevices"] }.to_json

      end
      bmc_setup
      begin
        case params[:function]
          #when "bootdevice"
          #  @bmc.chassis.config.bootdevice.to_json
          when "bootdevices"
            { :devices => @bmc.bootdevices }.to_json
          else
            { :error => "The action: #{params[:function]} is not a valid function" }.to_json
        end
      rescue => e
        log_halt 400, e
      end
    end

    put "/:host/chassis/power/?:action?" do
      # return hint on valid options
      if params[:action].nil?
        return { :actions => ["on", "off", "cycle", "soft"] }.to_json
      end
      bmc_setup
      begin
        case params[:action]
          when "on"
            { :action => params[:action], :result => @bmc.poweron }.to_json
          when "off"
            { :action => params[:action], :result => @bmc.poweroff }.to_json
          when "cycle"
            { :action => params[:action], :result => @bmc.powercycle }.to_json
          when "soft"
            { :action => params[:action], :result => @bmc.poweroff(true) }.to_json
          else
            { :error => "The action: #{params[:action]} is not a valid action" }.to_json
        end

      rescue => e
        log_halt 400, e
      end
    end

    put "/:host/chassis/config/?:function?/?:action?" do
      if params[:function].nil?
        return { :functions => ["bootdevice"] }.to_json
      end
      bmc_setup
      begin
        case params[:function]

          when "bootdevice"
            if params[:action].nil?
              return { :actions => @bmc.bootdevices, :options => ["reboot", "persistent"] }.to_json
            end
            case params[:action]
              when /pxe/
                { :action => params[:action], :result => @bmc.bootpxe(params[:reboot], params[:persistent]) }.to_json
              when /cdrom/
                { :action => params[:action], :result => @bmc.bootcdrom(params[:reboot], params[:persistent]) }.to_json
              when /bios/
                { :action => params[:action], :result => @bmc.bootbios(params[:reboot], params[:persistent]) }.to_json
              when /disk/
                { :action => params[:action], :result => @bmc.bootdisk(params[:reboot], params[:persistent]) }.to_json
              else
                # TODO: this appears to be deadcode; the only supported bootdevices are pxe, cdrom, bios, and disk
                if @bmc.bootdevices.include?(params[:action])
                  { :action => params[:action],
                    :result => @bmc.bootdevice = {:device => params[:action], :reboot => params[:reboot],
                                                  :persistent => params[:persistent]}
                  }.to_json
                else
                  { :error => "#{params[:action]} is not a valid boot device" }.to_json
                end
            end

          else
            { :error => "The action: #{params[:function]} is not a valid function" }.to_json
        end
      rescue => e
        log_halt 400, e
      end
    end

    put "/:host/chassis/identify/?:action?" do
      if params[:action].nil?
        return { :actions => ["on", "off"] }.to_json
      end
      bmc_setup
      begin
        case params[:action]
          when "on"
            { :action => params[:action], :result => @bmc.identifyon }.to_json
          when "off"
            { :action => params[:action], :result => @bmc.identifyoff }.to_json
          else
            { :error => "The action: #{params[:function]} is not a valid function" }.to_json
        end
      rescue => e
        log_halt 400, e
      end
    end

    private

    def bmc_setup
      # Either use the default provider or allow user to specify provider in request
      provider_type ||= params[:bmc_provider] || Proxy::BMC::Plugin.settings.bmc_default_provider
      provider_type.downcase! if provider_type
      if log_level = ::Proxy::BMC::Plugin.settings.provider_log_level
        # using the log_level below will cause rubyipmi to create its own log, instead of using the proxy log
        begin
          log_level = ::Logger.const_get(log_level.upcase)
        rescue
          logger.warn("Incorrect bmc log level supplied #{log_level}, ignoring setting")
          log_level = nil
        end
      end

      case provider_type
      when /ipmi/
        require 'bmc/ipmi'

        raise "unauthorized" unless auth.provided?
        raise "bad_authentication_request" unless auth.basic?

        username, password = auth.credentials

        # setting the log level must come before IPMI initialization
        # if the user supplies the provider_log_level all provider logs will be sent to
        # the provider specific log instead of the smart proxy logs
        # if the user doesn't supply the provider log level, all logs will be sent to the smart proxy logs
        # this was configured to make easier specific log output for BMC without having to see other logs
        if log_level
          Proxy::BMC::IPMI.log_level = log_level
        else
          # this causes rubyipmi to use the supplied logger, most actions in rubyipmi only output during Logger::DEBUG
          Proxy::BMC::IPMI.logger = logger
        end

        # check to see if provider is given and no default provider is set, search for installed providers
        unless Proxy::BMC::IPMI.installed?(provider_type)
          # check if provider_type is a valid type
          if Proxy::BMC::IPMI.providers.include?(provider_type)
            log_halt 400, "#{provider_type} is not installed, please install a ipmi provider"
          else
            log_halt 400, "Unrecognized or missing bmc provider type: #{provider_type}"
          end
        end

        # all the use of the http auth basic header to pass credentials
        args = { :host     => params[:host], :username     => username,
                 :password => password,      :bmc_provider => provider_type }
        @bmc = Proxy::BMC::IPMI.new(args)
      when "shell"
        require 'bmc/shell'
        @bmc = Proxy::BMC::Shell.new
      else
        log_halt 400, "Unrecognized or missing BMC type: #{provider_type}"
      end
    rescue => e
      log_halt 400, e
    end

    def auth
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
    end

  end
end
