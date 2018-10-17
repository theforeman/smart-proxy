require 'openssl'
require 'set'

module ::Proxy::PuppetCa::PuppetcaPuppetCert
  class PuppetcaImpl
    include ::Proxy::Log
    include ::Proxy::Util

    def sign certname
      puppetca("sign", certname)
    end

    def clean certname
      puppetca("clean", certname)
    end

    # list of all certificates and their state/fingerprint
    def list
      find_puppetca
      command = "#{@sudo} #{@puppetca} --list --all"
      logger.debug "Executing #{command}"
      response = `#{command}`
      unless $? == 0
        logger.warn "Failed to run puppetca: #{response}"
        raise "Execution of puppetca failed, check log files"
      end

      hash = {}
      response.split("\n").each do |line|
        hash.merge! certificate(line) rescue logger.warn("Failed to parse line: #{line}")
      end
      # merge all data into one
      # note that this ignores certificates which were revoked multiple times, displaying only the last
      # revocation state
      # additionally, we don't merge revocation info if the host has a pending certificate request
      hash.merge(ca_inventory) {|key, h1, h2| h1[:state] == "pending" ?  h1 : h1.merge(h2)}
    end

    def pending
      all.delete_if {|k,v| v[:state] != "pending"}
    end

    # helper to find puppetca and sudo binaries
    # checks if our CA really exists
    def find_puppetca
      ssl_dir = Pathname.new ssldir
      unless (ssl_dir + "ca").directory?
        logger.warn "PuppetCA: SSL/CA unavailable on this machine: ssldir not found at #{ssl_dir}"
        raise "SSL/CA unavailable on this machine"
      end

      default_path = ["/opt/puppet/bin", "/opt/puppet/sbin", "/opt/puppetlabs/bin"]
      @puppetca = which("puppetca", default_path) || which("puppet", default_path)

      unless File.exist?(@puppetca.to_s)
        logger.warn "unable to find puppetca binary"
        raise "unable to find puppetca"
      end
      # Append cert to the puppet command if we are not using the old puppetca command
      logger.debug "Found puppetca at #{@puppetca}"
      @puppetca << " cert" unless @puppetca.include?("puppetca")

      # Tell puppetca to use the ssl dir that Foreman has been told to use
      @puppetca << " --ssldir #{ssl_dir}"

      if use_sudo?
        @sudo = sudo_command || which("sudo")
        unless File.exist?(@sudo)
          logger.warn "unable to find sudo binary"
          raise "Unable to find sudo"
        end
        logger.debug "Found sudo at #{@sudo}"
        @sudo = "#{@sudo} -S"
      else
        @sudo = ""
      end
    end

    def ssldir
      Proxy::PuppetCa::PuppetcaPuppetCert::Plugin.settings.ssldir
    end

    def use_sudo?
      to_bool(::Proxy::PuppetCa::PuppetcaPuppetCert::Plugin.settings.puppetca_use_sudo, true)
    end

    def sudo_command
      ::Proxy::PuppetCa::PuppetcaPuppetCert::Plugin.settings.sudo_command
    end

    # parse the puppetca --list output
    def certificate str
      case str
        when /(\+|\-)\s+["]{0,1}(.*\w)["]{0,1}\s+\((\S+)\)/
          state = $1 == "-" ? "revoked" : "valid"
          return { $2.strip => { :state => state, :fingerprint => $3 } }
        when /\s*["]{0,1}(.*\w)["]{0,1}\s+\((\S+)\)/
          return { $1.strip => { :state => "pending", :fingerprint => $2 } }
        else
          return {}
      end
    end

    def ca_inventory
      inventory = Pathname.new(ssldir).join("ca","inventory.txt")
      raise "Unable to find CA inventory file at #{inventory}" unless File.exist?(inventory)
      crl_path = Pathname.new(ssldir).join("ca","ca_crl.pem")
      raise "Unable to find CRL" unless File.exist?(crl_path)
      compute_ca_inventory(File.read(inventory), File.read(crl_path))
    end

    def compute_ca_inventory(inventory_contents, crl_cert_contents)
      inventory = parse_inventory(inventory_contents)
      crl = revoked_serials(crl_cert_contents)
      inventory.each do |_, values|
        values[:state] = "revoked" if crl.include?(values[:serial])
      end
      inventory
    end

    def parse_inventory(inventory_contents)
      to_return = {}
      inventory_contents.each_line do |cert|
        # 0x005a 2011-04-16T07:12:46GMT 2016-04-14T07:12:46GMT /CN=uuid
        # 0x005c 2017-01-07T11:23:20GMT 2022-01-17T11:23:20GMT /CN=name.mcollective/OU=mcollective
        if cert =~ /(0(x|X)(\d|[a-f]|[A-F])+)\s+(\d+\S+)\s+(\d+\S+)\s+\/CN=([^\s\/]+)/
          to_return[$6] = {:serial => $1.to_i(16), :not_before => $4, :not_after => $5}
        end
      end
      to_return
    end

    def revoked_serials(crl_cert_contents)
      Set.new(OpenSSL::X509::CRL.new(crl_cert_contents).revoked.collect {|r| r.serial.to_i})
    end

    def puppetca mode, certname
      raise "Invalid mode #{mode}" unless mode =~ /^(clean|sign)$/
      find_puppetca
      certname.downcase!
      command = "#{@sudo} #{@puppetca} --#{mode} #{certname}"
      logger.debug "Executing #{command}"
      response = `#{command} 2>&1`
      if $?.success?
        logger.debug "#{mode}ed puppet certificate for #{certname}"
      elsif response =~ /Could not find client certificate/ || $?.exitstatus == 24
        logger.debug "Attempt to remove nonexistent client certificate for #{certname}"
        raise NotPresent, "Attempt to remove nonexistent client certificate for #{certname}"
      else
        logger.warn "Failed to run puppetca: #{response}"
        raise "Execution of puppetca failed, check log files"
      end
      $?.success?
    end
  end
end
