require 'tempfile'
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
        temporary = Tempfile.new([".#{destination.basename}.", '.tmp'], destination.dirname.to_s)
        begin
          temporary.binmode
          temporary.chmod(0o644)
          IO.copy_stream(io_entry, temporary)
          temporary.flush
          File.rename(temporary.path, destination.to_s)
        ensure
          temporary.close!
        end
      end
    end
  end
end
