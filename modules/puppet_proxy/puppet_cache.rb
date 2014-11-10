require 'json'

module Proxy::Puppet
  class PuppetCache
    extend Proxy::Log
    class << self
      def scan_directory_with_cache directory, environment, scanner
        logger.info("Running scan_directory on #{environment}: #{directory}")

        cache = read_from_cache(environment)

        if cache.has_key?(directory)
          lcache = cache[directory]
        else
          lcache = {}
        end

        seenmodules=[]
        changed    = false
        manifest   = Dir.glob("#{directory}/*").map do |path|
          puppetmodule = File.basename(path)
          mtime        = File.mtime(path)
          seenmodules.push(puppetmodule)

          lcache[puppetmodule] = {} unless lcache.has_key?(puppetmodule)
          if lcache[puppetmodule].has_key?(:timestamp) && lcache[puppetmodule][:timestamp] >= mtime
            logger.debug("Using cached class #{puppetmodule}")
            modulemanifest = lcache[puppetmodule][:manifest]
          else
            changed = true
            logger.info("Scanning class #{puppetmodule}")
            modulemanifest = Dir.glob("#{path}/manifests/**/*.pp").map do |filename|
              scanner.scan_manifest File.read(filename), filename
            end

            lcache[puppetmodule][:timestamp]= Time.new
            lcache[puppetmodule][:manifest] = modulemanifest
          end
          modulemanifest
        end.compact.flatten

        if changed
          logger.info("Cache file need to be updated for #{environment}: #{directory}")
          # Clean obsolete cache modules
          oldlength = lcache.length
          lcache.delete_if { |key, value| !seenmodules.include?(key) }
          logger.info("Cleaning #{oldlength - lcache.length } modules from cache") if oldlength - lcache.length > 0

          cache[directory] = lcache
          write_to_cache(cache, environment)
          logger.info("Cache file updated for #{environment}: #{directory}")
        end

        manifest
      end

      def read_from_cache environment
        cachefile = File.expand_path("cache_#{environment}.json", Proxy::Puppet::Plugin.settings.cache_location)

        if File.exist?(cachefile)
          JSON.parse(File.read(cachefile))
        else
          {}
        end
      end

      def write_to_cache cache, environment
        cache_dir = Proxy::Puppet::Plugin.settings.cache_location
        FileUtils.mkdir_p(cache_dir) unless File.directory?(cache_dir)

        cachefile = File.expand_path("cache_#{environment}.json", cache_dir)
        lock =  Proxy::FileLock.try_locking(cachefile)

        unless lock.nil?
          tmpfile = cachefile + '.tmp'
          File.open(tmpfile, 'w') { |file| file.write(cache.to_json) }
          File.rename(tmpfile, cachefile)
          Proxy::FileLock.unlock(lock)
        end
      end
    end
  end
end