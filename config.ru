$LOAD_PATH.unshift *Dir[File.expand_path("../lib", __FILE__), File.expand_path("../modules", __FILE__)]

require 'smart_proxy_main'
::Proxy::Plugins.configure_loaded_plugins
::Proxy::Plugins.enabled_plugins.each {|p| instance_eval(p.https_rackup)}
