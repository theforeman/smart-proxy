#!/usr/bin/env ruby

$LOAD_PATH.unshift *Dir["#{File.dirname(__FILE__)}/lib"]

require "rubygems"
require "sinatra"
require "proxy"
require "json"


get "/tftp/path" do
  SETTINGS[:tftproot].to_s
end

post "/tftp/fetch_boot_file" do
  begin
    Proxy::TFTP.fetch_boot_file(params[:prefix], params[:path])
  rescue => e
    halt 400, e
  end
end

# create a new TFTP reservation
post "/tftp/:mac" do
  mac = params[:mac]
  syslinux = params[:syslinux_config]
  begin
    halt 400 unless Proxy::TFTP.create(mac, syslinux)
  rescue Exception => e.to_s
    halt 400, e
  end
end

# delete a record from a network
delete "/tftp/:mac" do
    halt 400 unless Proxy::TFTP.remove(params[:mac])
end

post "/puppet/run" do
  hosts = params[:nodes]
  halt 400, "No nodes defined" unless hosts
  halt 500, "Check Log files" unless Proxy::Puppet.run hosts
end

put "/puppet/ca/autosign" do
  content_type :json
  certnames = params[:cert]
  case params[:state]
  when 'enable'
    return certnames.collect{|certname| Proxy::PuppetCA.sign(certname)}.to_json
  when 'disable'
    return certnames.collect {|certname| Proxy::PuppetCA.disable(certname)}.to_json
  else
    render 400, "Unknown state"
  end
end

delete "/puppet/ca/:cert" do
  content_type :json
  certnames = params[:cert]
  certnames.collect {|certname| Proxy::PuppetCA.clean(certname)}.to_json
end
