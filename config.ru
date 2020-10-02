$LOAD_PATH.unshift(*Dir[File.expand_path('lib', __dir__), File.expand_path('modules', __dir__)])

require 'smart_proxy_main'
require 'proxy/app'
plugins = ::Proxy::Plugins.instance
::Proxy::PluginInitializer.new(plugins).initialize_plugins
run ::Proxy::App.new(plugins)
