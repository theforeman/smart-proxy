module Proxy::TFTP
  class SystemImageApi < ::Sinatra::Base
    helpers ::Proxy::Helpers

    get "/*" do
      file = Pathname.new(params[:splat].first).cleanpath
      root = Pathname.new(Proxy::TFTP::Plugin.settings.system_image_root).expand_path.cleanpath
      joined_path = File.join(root, file)
      log_halt(404, "Not found") unless File.exist?(joined_path)
      real_file = Pathname.new(joined_path).realpath
      log_halt(403, "Invalid or empty path") unless real_file.fnmatch?("#{root}/**")
      log_halt(403, "Directory listing not allowed") if File.directory?(real_file)
      log_halt(503, "Not a regular file") unless File.file?(real_file)
      send_file real_file
    end
  end
end
