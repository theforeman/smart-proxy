require 'proxy/log'
require 'openssl'

module Proxy::PuppetCA
  extend Proxy::Log
  extend Proxy::Util

  class << self

    def sign certname
      puppetca("sign", certname)
    end

    def clean certname
      puppetca("clean", certname)
    end

    #remove certname from autosign if exists
    def disable certname
      raise "No such file #{autosign_file}" unless File.exists?(autosign_file)

      entries  = open(autosign_file, File::RDONLY).readlines.collect do |l|
        l if l.chomp != certname
      end.uniq.compact
      autosign = open(autosign_file, File::TRUNC|File::RDWR)
      autosign.write entries
      autosign.close
      logger.info "Removed #{certname} from autosign"
    end

    # add certname to puppet autosign file
    # parameter is certname to use
    def autosign certname
      FileUtils.touch(autosign_file) unless File.exist?(autosign_file)

      autosign = open(autosign_file, File::RDWR)
      # Check that we don't have that host already
      found = false
      autosign.each_line { |line| found = true if line.chomp == certname }
      autosign.puts certname if found == false
      autosign.close
      logger.info "Added #{certname} to autosign"
    end

    # list of hosts which are now allowed to be installed via autosign
    def autosign_list
      File.exist?(autosign_file) ? File.read(autosign_file).split : []
    end

    # list of all certificates and their state/fingerprint
    def list
      find_puppetca
      command = "#{@sudo} -S #{@puppetca} --list --all"
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

    private

    # helper to find puppetca and sudo binaries
    # checks if our CA really exists
    def find_puppetca
      ssl_dir = Pathname.new ssldir
      unless (ssl_dir + "ca").directory?
        logger.warn "PuppetCA: SSL/CA unavailable on this machine"
        raise "SSL/CA unavailable on this machine"
      end

      @puppetca = which("puppetca", "/usr/sbin")
      unless File.exists?("#{@puppetca}")
        logger.warn "unable to find puppetca binary"
        raise "unable to find puppetca"
      end
      logger.debug "Found puppetca at #{@puppetca}"

      @sudo = which("sudo", "/usr/bin")
      unless File.exists?("#{@sudo}")
        logger.warn "unable to find sudo binary"
        raise "Unable to find sudo"
      end
      logger.debug "Found sudo at #{@sudo}"

    end

    def ssldir
      SETTINGS.ssldir || "/var/lib/puppet/ssl"
    end

    def puppetdir
      SETTINGS.puppetdir || "/etc/puppet"
    end

    def autosign_file
      "#{puppetdir}/autosign.conf"
    end

    # parse the puppetca --list output
    def certificate str
      case str
        when /(\+|\-)\s+(.*)\s+\((\S+)\)/
          state = $1 == "-" ? "revoked" : "valid"
          return { $2 => { :state => state, :fingerprint => $3 } }
        when /(.*)\s+\((\S+)\)/
          return { $1 => { :state => "pending", :fingerprint => $2 } }
        else
          return {}
      end
    end

    def ca_inventory
      inventory = Pathname.new(ssldir).join("ca","inventory.txt")
      raise "Unable to find CA inventory file at #{inventory}" unless File.exists?(inventory)
      hash = {}
      # 0x005a 2011-04-16T07:12:46GMT 2016-04-14T07:12:46GMT /CN=uuid
      File.read(inventory).each_line do |cert|
        if cert =~ /(0(x|X)(\d|[a-f]|[A-F])+)\s+(\d+\S+)\s+(\d+\S+)\s+\/CN=(\S+)/
          hash[$6] = {:serial => $1.to_i(16), :not_before => $4, :not_after => $5}
        end
      end
      crl = revoked_serials
      hash.each do |cert,values|
        values[:state] = "revoked" if crl.include?(values[:serial])
      end
      hash
    end

    def revoked_serials
      crl = Pathname.new(ssldir).join("ca","ca_crl.pem")
      raise "Unable to find CRL" unless File.exists?(crl)

      crl = OpenSSL::X509::CRL.new(File.read(crl))
      crl.revoked.collect {|r| r.serial}
    end

    def puppetca mode, certname
      raise "invalid mode #{mode}" unless mode =~ /^(clean|sign)$/
      find_puppetca
      certname.downcase!
      command = "#{@sudo} -S #{@puppetca} --#{mode} #{certname}"
      logger.debug "executing #{command}"
      response = `#{command}`
      unless $?.success?
        logger.warn "Failed to run puppetca: #{response}"
        raise "Execution of puppetca failed, check log files"
      end
      $?.success?
    end
  end
end
