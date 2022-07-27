module Proxy
  class ArchiveExtract < Proxy::Util::CommandTask
    include Util

    def initialize(image_path, file_in_image, dst_path)

      args = [which('isoinfo')]

      # read the file
      args << "-R"
      # set image path
      args += ["-i", image_path.to_s]
      # set file path within the image
      args += ["-x", file_in_image.to_s]
      # save destination path
      @dst_path = dst_path

      super(args)
    end

    def start
      super do
        File.open(@dst_path, "w+") { |file| file.write(@output) }
      end
    end
  end
end
