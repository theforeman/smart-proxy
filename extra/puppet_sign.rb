#!/usr/bin/env ruby
#
# This takes a base64 encoded CSR as input and uploads it to foreman-proxy for analysis.
# It is used to verify if the CSR should be signed by PuppetCA.
#

require 'net/http'
require 'net/https'
require 'fileutils'
require 'json'
require 'yaml'
require 'socket'

def log(message)
  puts message
  `logger "[PuppetCA CSR Verify] #{message}"`
end

csr = STDIN.read

if RbConfig::CONFIG['host_os'] =~ /freebsd|dragonfly/i
  settings_file = '/usr/local/etc/foreman-proxy/settings.yml'
else
  settings_file = '/etc/foreman-proxy/settings.yml'
end
SETTINGS         = YAML.load_file(settings_file)
PUPPETCA         = YAML.load_file(SETTINGS[:settings_directory] + '/puppetca.yml')
unless PUPPETCA[:enabled]
  log('PuppetCA smart-proxy module is not enabled!')
  exit 1
end
protocol         = PUPPETCA[:enabled] == true ? 'https' : PUPPETCA[:enabled]
port             = protocol == 'https' ? SETTINGS[:https_port] : SETTINGS[:http_port]
fqdn             = Socket.gethostbyname(Socket.gethostname).first
# e.g. POST https://hostname.localdomain.com:8443/puppet/ca/validate
uri              = URI.parse("#{protocol}://#{fqdn}:#{port}/puppet/ca/validate")
res              = Net::HTTP.new(uri.host, uri.port)
if protocol == 'https'
  res.use_ssl      = true
  res.ca_file      = SETTINGS[:ssl_ca_file]
  res.verify_mode  = OpenSSL::SSL::VERIFY_PEER
  res.cert         = OpenSSL::X509::Certificate.new(File.read(SETTINGS[:ssl_certificate]))
  res.key          = OpenSSL::PKey::RSA.new(File.read(SETTINGS[:ssl_private_key]), nil)
end
res.open_timeout = SETTINGS[:timeout]
res.read_timeout = SETTINGS[:timeout]
req              = Net::HTTP::Post.new(uri.request_uri)
req.add_field('Accept', 'application/json,version=2')
req.body = csr
begin
  res.start do |http|
    response = http.request(req)
    exit 0 if response.code == '200'
    log("Called smart proxy for CSR verification, but received a #{response.code} http status.")
    exit 1
  end
rescue => e
  log("Failed to call smart proxy for CSR verification. " + e.to_s)
  exit 1
end
