require 'proxy/log'
module Proxy::Puppetca
  extend Proxy::Log
  extend Proxy::Util

  class << self

    def clean fqdn
      fqdn.downcase!
      sudo = which("sudo", "/usr/bin")
      puppetca = which("puppetca", "/usr/sbin")
      ssl_dir = Pathname.new ssldir
      unless (ssl_dir + "ca").directory? and File.exists? "#{puppetca}"
        logger.error "PuppetCA: SSL/CA or puppetca unavailable on this machine"
        return false
      end
      begin
        command = "#{sudo} -S #{puppetca} --clean #{fqdn} < /dev/null > /dev/null"
        logger.info system(command)
        return true
      rescue StandardError => e
        logger.info "PuppetCA: clean failed: #{e}"
        false
      end
    end

    #remove fqdn from autosign if exists
    def disable fqdn
      if File.exists? "#{puppetdir}/autosign.conf"
        entries = open("#{puppetdir}/autosign.conf", File::RDONLY).readlines.collect do |l|
          l if l.chomp != fqdn
        end.uniq.compact
        autosign = open("/#{puppetdir}/autosign.conf", File::TRUNC|File::RDWR)
        autosign.write entries
        autosign.close
      end
    end

    # add fqdn to puppet autosign file
    # parameter is fqdn to use
    def sign fqdn
      FileUtils.touch("#{puppetdir}/autosign.conf") unless File.exist?("#{puppetdir}/autosign.conf")

      autosign = open("#{puppetdir}/autosign.conf", File::RDWR)
      # Check that we don't have that host already
      found = false
      autosign.each_line { |line| found = true if line.chomp == fqdn }
      autosign.puts fqdn if found == false
      autosign.close
    end

    private

    def ssldir
      SETTINGS[:ssldir] || "/var/lib/puppet/ssl"
    end

    def puppetdir
      SETTINGS[:puppetdir] || "/etc/puppet"
    end

  end
end
