require 'fileutils'
require 'open3'
require 'tmpdir'

module Proxy::TFTP
  module Extractor
    module Iso
      extend Proxy::Util

      def self.extract(archive, files, symlinks)
        extract_files(archive, files) unless files.empty?

        symlinks.each do |link, target|
          Proxy::TFTP.create_relative_symlink(link, target)
        end
      end

      def self.extract_files(archive, files)
        files.each_value { |destination| Proxy::TFTP.ensure_tftp_file_path(destination) }

        commands = []
        bsdtar = which('bsdtar')
        xorriso = which('xorriso')
        commands << [:bsdtar, bsdtar] if bsdtar
        commands << [:xorriso, xorriso] if xorriso
        raise 'Cannot extract ISO boot files, neither bsdtar nor xorriso is available' if commands.empty?

        errors = []
        successful = commands.any? do |tool, executable|
          error = extract_with(tool, executable, archive, files)
          next true if error.nil?

          errors << "#{executable}: #{error.strip}"
          false
        end
        return if successful

        raise "Cannot extract ISO boot files: #{errors.join('; ')}"
      end

      def self.extract_with(tool, executable, archive, files)
        Dir.mktmpdir('tftp-iso-') do |staging|
          command = extraction_command(tool, executable, archive, files, staging)

          task = Proxy::Util::CommandTask.new(command)
          task.start
          status = task.join

          return "Command failed with status #{status}" unless status.zero?

          staged_files = files.map do |member, destination|
            staged = Pathname.new(staging).join(member)
            [staged, destination]
          end
          return 'requested ISO member was not extracted' unless staged_files.all? { |staged, _destination| regular_file?(staged) }

          staged_files.each do |staged, destination|
            File.chmod(0o644, staged)
            FileUtils.mv staged.to_s, destination.to_s, force: true
          end
          nil
        end
      end

      def self.extraction_command(tool, executable, archive, files, staging)
        case tool
        when :bsdtar
          [executable, '-xf', archive.to_s, '-C', staging, *files.keys]
        when :xorriso
          files.each_with_object([executable, '-osirrox', 'on', '-indev', archive.to_s]) do |(member, _destination), command|
            command.concat(['-extract_single', "/#{member}", Pathname.new(staging).join(member).to_s])
          end
        end
      end

      def self.regular_file?(path)
        File.lstat(path).file?
      rescue Errno::ENOENT
        false
      end
    end
  end
end
