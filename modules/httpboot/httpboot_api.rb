class Proxy::HttpbootApi < Sinatra::Base
  helpers ::Proxy::Helpers

  get "/*" do
    file = Pathname.new(params[:splat].first).cleanpath
    root = Pathname.new(Proxy::Httpboot::Plugin.settings.root_dir).expand_path.cleanpath
    # special handling for Grub2 (https://bugzilla.redhat.com/show_bug.cgi?id=1616395)
    if env['REQUEST_PATH'] && env['REQUEST_PATH'].match(/^\/grub2\/.*/)
      joined_path = File.join(root, env['REQUEST_PATH'])
    elsif env['REQUEST_PATH'] && env['REQUEST_PATH'].match(/^\/(grub.cfg|grub.cfg-.*)/)
      joined_path = File.join(root, 'grub2', env['REQUEST_PATH'])
    else
      joined_path = File.join(root, file)
    end
    log_halt(404, "Not found") unless File.exist?(joined_path)
    real_file = Pathname.new(joined_path).realpath
    log_halt(403, "Invalid or empty path") unless real_file.fnmatch?("#{root}/**")
    log_halt(403, "Directory listing not allowed") if File.directory?(real_file)
    log_halt(503, "Not a regular file") unless File.file?(real_file)
    send_file real_file
  end
end
