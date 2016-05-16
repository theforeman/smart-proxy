$LOAD_PATH.unshift *Dir[File.expand_path("../lib", __FILE__), File.expand_path("../modules", __FILE__)]

require 'smart_proxy_main'
::Proxy::PluginInitializer.new(::Proxy::Plugins.instance).initialize_plugins
::Proxy::Plugins.instance.select {|p| p[:state] == :running && p[:https_enabled]}.each {|p| instance_eval(p[:class].https_rackup)}
