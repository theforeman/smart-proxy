require 'winrm'
require 'json'
require 'realm/client'

module Proxy::Realm
  class  ActiveDirectory < Client
    include Proxy::Util

    def initialize
      errors = []
      errors << "WinRM endpoint not configured" unless Proxy::Realm::Plugin.settings.winrm_endpoint
      errors << "WinRM user / password not configured #{Proxy::Realm::Plugin.settings.winrm_user}" unless Proxy::Realm::Plugin.settings.winrm_user && Proxy::Realm::Plugin.settings.winrm_password

      logger.info "active directory: WinRM endpoint is '#{Proxy::Realm::Plugin.settings.winrm_endpoint}'"

      if errors.empty?
        begin
          @winrm_endpoint = WinRM::WinRMWebService.new(
              Proxy::Realm::Plugin.settings.winrm_endpoint,
              :negotiate,
              :user => Proxy::Realm::Plugin.settings.winrm_user,
              :pass => Proxy::Realm::Plugin.settings.winrm_password
          )
          @import_cmdlets = 'Import-Module ActiveDirectory -cmdlet New-ADComputer,Get-ADComputer,Get-ADDomain,Remove-ADComputer,Get-ADOrganizationalUnit,Move-ADObject'
          ad_domain = parse_wimrm(execute('Get-AdDomain'))
          @realm_name = ad_domain[:Name] # we could also use :NetBIOSName
          logger.info "active directory: using realm #{@realm_name}"
          @winrm_execution_timeout = Proxy::Realm::Plugin.settings.winrm_timeout
          @computer_container = Proxy::Realm::Plugin.settings.computer_container || ad_domain[:ComputersContainer]
          logger.info "active directory: using computer container #{@computer_container}"
          @sync_hostgroups = Proxy::Realm::Plugin.settings.hostgroup_sync || false
          logger.info "syncing hostgroups to #{@computer_container}" if @sync_hostgroups
        end
      else
        raise Proxy::Realm::Error.new errors.join(", ")
      end
    end

    def check_realm realm
      raise Proxy::Realm::Error.new "Unknown realm #{realm}" unless realm.casecmp(@realm_name).zero?
    end

    # find by dns hostname; return host object or false
    def find hostname
      # This might be a hard one: associating the right computer account
      # using ldap results in a zero exit code but might not find the correct host, though it should at least not result
      # in dubs. We could also guess the SamAccountName here using "#{params[:hostname].split('.').first}$"
      host = execute "Get-Adcomputer -LDAPFilter \"(DNSHostname=#{hostname})\"" unless hostname.nil?
      parse_wimrm(host) if host[:data].any?
    end

    def create realm, params
      check_realm realm
      host = find params[:hostname]
      hostgroup = params[:userclass]
      sam_acc_name = "#{params[:hostname].split('.').first}"
      if @sync_hostgroups
        container = hostgroup_to_dn hostgroup
      else
        container = @computer_container
      end
      require_otp = false
      otp = (0...99).map { ('a'..'z').to_a[rand(26)] }.join
      ps_script = nil

      # Determine if we're updating a host or creating a new one
      if host.nil? # create a new host
        logger.debug "Creating new active directory object '#{params[:hostname]}'"
        ps_script = "New-AdComputer -Name #{sam_acc_name} -DNSHostName #{params[:hostname]} -Path \"#{container}\" -AccountPassword (ConvertTo-SecureString \"#{otp}\" -asplaintext -force) -PassThru"
        require_otp = true
      elsif host && params[:rebuild] == "true" # rebuild host
        logger.debug "Resetting existing active directory object '#{params[:hostname]}'"
        ps_script = "Set-ADAccountPassword -Identity \"#{host[:DistinguishedName]}\" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText \"#{otp}\" -Force) -PassThru"
        require_otp = true
      elsif host && @sync_hostgroups && container != host[:DistinguishedName] # move host to new OU
        logger.debug "Moving host '#{params[:hostname]}' to target ou '#{container}'"
        ps_script = "Move-ADObject -Identity \"#{host[:DistinguishedName]}\" -TargetPath \"#{container}\" -PassThru"
      else
        result = {:message => "Nothing to do"}
      end
      if ps_script
        result = parse_wimrm(execute(ps_script)) if check_ou container
        result.merge!(:randompassword => otp) if require_otp
      end
      JSON.pretty_generate(result)
    end

    def delete realm, hostname
      check_realm realm
      host = find hostname
      raise Proxy::Realm::NotFound, "Host #{hostname} not found in realm!" unless host
      begin
        execute "Remove-ADComputer -Identity #{host[:ObjectGUID]} -confirm:$false"
      end
      JSON.pretty_generate(:message => "Deleted #{hostname} realm #{realm}")
    end

    def execute ps_script, strict_error_checking = true
      con_secs = 5
      exec_secs = @winrm_execution_timeout || 15
      result = nil
      complete_ps_script = "try {#{@import_cmdlets}; #{ps_script}|ConvertTo-Json} catch {'winrm_error'}"
      begin
        timeout(con_secs) do
          @executor = @winrm_endpoint.create_executor # actually connect to winrm endpoint
        end
        timeout(exec_secs) do
          logger.debug "Running powershell script: '#{complete_ps_script.gsub(/\(.*ConvertTo-SecureString.*\)/, '(XXX)')}'"
          result = @executor.run_powershell_script(complete_ps_script) # run our command
        end
        if strict_error_checking && result.stdout == 'winrm_error'
          raise Proxy::Realm::Error.new "Error executing powershell script"
        end
      rescue TimeoutError
        raise Proxy::Realm::Error.new "Timeout connecting to WinRM endpoint: '#{Proxy::Realm::Plugin.settings.winrm_endpoint}'"
      rescue => e
        raise Proxy::Realm::Error.new "General command execution error '#{Proxy::Realm::Plugin.settings.winrm_endpoint}': #{e.message}"
      end
      nil if result.stdout == 'winrm_error'
      result
    end

    def parse_wimrm executor
      JSON.parse(executor.stdout, :symbolize_names => true)
    end

    def hostgroup_to_dn hostgroup
      result = ''
      hostgroup.split('/').reverse.each do |group|
        result << "OU=#{group},"
      end
      "#{result}#{@computer_container}"
    end

    def check_ou container_dn
      ou = execute "Get-ADOrganizationalUnit -Identity \"#{container_dn}\"", false
      if ou.nil?
        raise Proxy::Realm::Error.new "Container does not exist: #{container_dn}"
      end
      true
    end
  end
end
