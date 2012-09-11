$LOAD_PATH.unshift *Dir["#{File.dirname(__FILE__)}/lib"]

require 'smart_proxy'
run SmartProxy
