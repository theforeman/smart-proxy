module ::Proxy::PuppetCa::HostnameWhitelisting
  class Autosigner
    include ::Proxy::Log
    include ::Proxy::Util

    def autosign_file
      Proxy::PuppetCa::HostnameWhitelisting::Plugin.settings.autosignfile
    end

    # remove certname from autosign if exists
    def disable(certname)
      raise "No such file #{autosign_file}" unless File.exist?(autosign_file)

      found = false
      entries = File.readlines(autosign_file).collect do |l|
        if l.chomp != certname
          l
        else
          found = true
          nil
        end
      end.uniq.compact
      if found
        open(autosign_file, File::TRUNC|File::RDWR) do |autosign|
          autosign.write entries.join
        end
        logger.debug "Removed #{certname} from autosign"
      else
        logger.debug "Attempt to remove nonexistent client autosign for #{certname}"
        raise ::Proxy::PuppetCa::NotPresent, "Attempt to remove nonexistent client autosign for #{certname}"
      end
    end

    # add certname to puppet autosign file
    # parameter is certname to use
    def autosign(certname, ttl)
      FileUtils.touch(autosign_file) unless File.exist?(autosign_file)

      open(autosign_file, File::RDWR) do |autosign|
        # Check that we don't have that host already
        found = autosign.readlines.find { |line| line.chomp == certname }
        autosign.puts certname unless found
      end
      logger.debug "Added #{certname} to autosign"
    end

    # list of hosts which are now allowed to be installed via autosign
    def autosign_list
      return [] unless File.exist?(autosign_file)
      File.read(autosign_file).split("\n").reject do |v|
        v =~ /^\s*#.*|^$/ ## Remove comments and empty lines
      end.map(&:chomp)
    end
  end
end
