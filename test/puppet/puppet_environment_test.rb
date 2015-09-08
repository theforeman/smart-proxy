require 'test_helper'
require 'puppet_proxy/environment'

class PuppetEnvironmentTest < Test::Unit::TestCase

  def setup
    @environment = Proxy::Puppet::Environment.new(:name => 'test', :paths => ['path_1'])
  end

  def test_should_use_environments_retriever_to_get_environments
    environments_retriever = mock()
    environments_retriever.expects(:all).returns([])

    @environment.environments_retriever = environments_retriever
    @environment.all
  end

  def test_should_use_puppet_cache_when_enumerating_classes
    puppet_cache = mock()
    puppet_cache.expects(:scan_directory).with('path_1', 'test').returns([])

    @environment.puppet_class_scanner = puppet_cache
    @environment.classes
  end
end
