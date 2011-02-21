#!/usr/bin/ruby
# == Synopsis
#
# Queries a remote smart proxy via https
#
# == Usage
#
# query.rb [options] url
#
# -h, --help
#   show help
#
# --key [filename]
#   The ssl private key
#
# --cert [filename]
#   The ssl certificate file
#
# --ca [filename]
#   The ssl Certificate Authority file.
#   This will also contain the public keys of any host that you wish to grant access to this proxy
#
# --json
#   Request the reply in json format rather than HTML
#
# -v, --verbose
#   Operations are displayed in detail
#
# If the ssl keys are not specified then defaults are chosen based upon the platform

require 'rubygems'
require 'rest-client'
require 'getoptlong'
require 'rdoc/usage'
require 'pathname'

opts = GetoptLong.new([ '--verbose', '-v', GetoptLong::NO_ARGUMENT ],
                      [ '--help',    '-h', GetoptLong::NO_ARGUMENT ],
                      [ '--key',           GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--cert',          GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--ca',            GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--verb',          GetoptLong::REQUIRED_ARGUMENT ],
                      [ '--json',          GetoptLong::NO_ARGUMENT ]
    )
json = false
verb = :get
key = cert = ca = verbose = nil
for opt, arg in opts
  case opt
    when '--help'
      RDoc::usage
    when '--key'
      key = arg
    when '--cert'
      cert = arg
    when '--ca'
      ca = arg
    when '--json'
      json = true
    when '--verbose'
      verbose = true
    when '--verb'
      verb = arg.to_sym
  end
end

unless key and cert and ca
  if PLATFORM =~ /mingw/
    origin = Pathname.new(__FILE__).dirname.parent.join "config"
    key    = origin.join "private.pem" unless key
    cert   = origin.join "signed.pem"  unless cert
    ca     = origin.join "ca.pem"      unless ca
  else
    hostfile = %x{hostname -f}.chomp + ".pem"
    key    = "/var/lib/puppet/ssl/private_keys/" + hostfile unless key
    cert   = "/var/lib/puppet/ssl/certs/" + hostfile        unless cert
    ca     = "/var/lib/puppet/ssl/certs/ca.pem"             unless ca
  end
end

url = ARGV.shift
if url !~ /^https:\/\/.*:4567/
  puts "Malformed or missing URL:           " + (url.nil? ? "MISSING" : url.to_s)
  puts "It should look something like this: " + 'https://brssa009.brs.someware.com:4567/dhcp/192.168.11.0'
  exit -1
end

puts "#{$0} --verb #{verb} --key #{key} --cert #{cert} --ca #{ca} #{json ? "--json" : ""} --verbose #{url}" if verbose

c = RestClient::Resource.new(
    url,
    :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(cert)),
    :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(key)),
    :ssl_ca_file      =>  ca
  )

begin
  json_args = {}
  if json
    json_args = {:accept => :json, :content_type => :json}
    unless ARGV.empty?
      # then merge any optional POST parameters
      json_args.update(eval(ARGV.shift))
    end
  end
  response = c.send(verb, json_args)
  puts response.code

  puts response.to_str
rescue => e
  message  = "Exception: '" + e.message + "'"
  message += " with '#{e.response}'" if e.respond_to? :response
  puts message
end
