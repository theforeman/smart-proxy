require 'fileutils'
require 'English'
require 'rubygems/package'
require 'rubygems/package/tar_reader'
require 'zlib'

module Proxy::TFTP
  module Extractor
    module Tgz
      def self.extract(archive, files, symlinks)
        extracted = {}

        Zlib::GzipReader.open(archive.to_s) do |gzip|
          Gem::Package::TarReader.new(gzip) do |tar|
            tar.each do |entry|
              member = Proxy::TFTP.archive_member_path(entry.full_name)
              next unless files.key?(member)
              raise "Cannot extract boot file, archive member is not a regular file: #{member}" unless entry.file?

              write_extracted_file(files[member], entry)
              extracted[member] = true
            end
          end
        end

        missing = files.keys.reject { |member| extracted[member] }
        raise "Cannot extract boot file, archive members not found: #{missing.join(', ')}" unless missing.empty?

        symlinks.each do |link, target|
          Proxy::TFTP.create_relative_symlink(link, target)
        end
      end

      def self.write_extracted_file(destination, io_entry)
        Proxy::TFTP.ensure_tftp_file_path(destination)
        temporary = destination.dirname.join(".#{destination.basename}.#{$PROCESS_ID}.tmp")
        File.open(temporary, 'wb', 0o644) { |file| IO.copy_stream(io_entry, file) }
        File.chmod(0o644, temporary)
        FileUtils.mv temporary, destination.to_s, force: true
      ensure
        FileUtils.rm_f temporary.to_s if temporary
      end
    end
  end
end
