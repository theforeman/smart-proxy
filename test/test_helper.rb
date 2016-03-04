require "test/unit"
require 'fileutils'

$: << File.join(File.dirname(__FILE__), '..', 'lib')
$: << File.join(File.dirname(__FILE__), '..', 'modules')

logdir = File.join(File.dirname(__FILE__), '..', 'logs')
FileUtils.mkdir_p(logdir) unless File.exist?(logdir)

# Make sure that tests put their temp files in a controlled location
# Clear temp file before each test run
ENV['TMPDIR'] = 'test/tmp'
FileUtils.rm_f Dir.glob 'test/tmp/*.tmp'

require "mocha/setup"
require "rack/test"

require 'smart_proxy_for_testing'
require 'provider_interface_validation/dhcp_provider'

include DhcpProviderInterfaceValidation

def hash_symbols_to_strings(hash)
  Hash[hash.collect{|k,v| [k.to_s,v]}]
end
