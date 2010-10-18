post "/puppet/run" do
  hosts = params[:nodes]
  halt 400, "No nodes defined" unless hosts
  halt 500, "Check Log files" unless Proxy::Puppet.run hosts
end
