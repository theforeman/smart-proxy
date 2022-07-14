module Proxy
  class ArchiveExtract < Proxy::Util::CommandTask
    include Util

    def initialize(src, dst, skip_existing = true)

      args = [which('7z')]

      # extract command
      args << "x"
      # source file
      args << src.to_s
      # skip existing files
      args << "-aos" if skip_existing
      # destination directory
      args << "-o#{dst}"

      super(args)
    end
  end
end
