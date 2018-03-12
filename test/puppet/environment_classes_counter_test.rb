require 'test_helper'
require 'puppet_proxy_common/api_request'
require 'puppet_proxy_puppet_api/v3_api_request'
require 'puppet_proxy_common/errors'
require 'puppet_proxy_common/puppet_class'
require 'puppet_proxy_puppet_api/v3_environment_classes_api_classes_retriever'

class EnvironmentClassesCounterTest < Test::Unit::TestCase
  class CounterForTesting < Proxy::PuppetApi::EnvironmentClassesCounter
    attr_accessor :etag_cache, :first_pass_in_progress, :total_number_of_classes
  end

  def setup
    @environment_classes_api = Object.new
    @environments_retriever = Object.new
    @counter = CounterForTesting.new(@environment_classes_api, @environments_retriever, 10, 10)
  end

  def test_class_count
    @counter.etag_cache['testing'] = [100, '12345']
    assert_equal 100, @counter.count_classes_in_environment('testing')
  end

  def test_class_count_should_raise_exception_for_nonexistent_environment
    assert_raises(Proxy::Puppet::EnvironmentNotFound) do
      @counter.count_classes_in_environment('nonexistent')
    end
  end

  def test_class_count_should_raise_an_exception_if_initial_cache_update_in_progress
    @counter.first_pass_in_progress = true
    assert_raises(Proxy::Puppet::NotReady) do
      @counter.count_classes_in_environment('testing')
    end
  end

  def test_all_classes_count
    @counter.etag_cache = {'testing' => [100, '12345'], 'testing-2' => [200, '12345']}
    assert_equal({'testing' => {:class_count => 100}, 'testing-2' => {:class_count => 200}}, @counter.count_all_classes)
  end

  def test_all_classes_count_should_raise_exception_if_initial_cache_update_in_progress
    @counter.first_pass_in_progress = true
    assert_raises(Proxy::Puppet::NotReady) do
      @counter.count_all_classes
    end
  end

  ENVIRONMENT_CLASSES_RESPONSE =<<EOL
{
  "files": [
    {
      "classes": [{"name": "dns::config", "params": []}],
      "path": "/manifests/config.pp"
    },
    {
      "classes": [{"name": "dns::install", "params": []}],
      "path": "/manifests/install.pp"
    },
    {
      "error": "Syntax error at '=>' at /manifests/witherror.pp:20:19",
      "path": "/manifests/witherror.pp"
    }],
  "name": "test_environment"
}
EOL
  def test_update_class_counts
    environment_name = 'test_environment'
    @environments_retriever.expects(:all).returns(
        [Proxy::Puppet::Environment.new(environment_name, 'test_path_1')])
    @environment_classes_api.expects(:list_classes).with(environment_name, nil, Proxy::PuppetApi::MAX_PUPPETAPI_TIMEOUT).
      returns([JSON.load(ENVIRONMENT_CLASSES_RESPONSE), 42])
    @counter.update_class_counts

    assert_equal 2, @counter.count_classes_in_environment(environment_name)
    _, etag = @counter.etag_cache[environment_name]
    assert_equal 42, etag
    assert_equal({'test_environment' => {:class_count => 2}}, @counter.count_all_classes)
  end

  def test_update_class_counts_when_etag_did_not_change
    environment_name = 'test_environment'
    @counter.etag_cache[environment_name] = [100, 42]
    @environments_retriever.expects(:all).
      returns([Proxy::Puppet::Environment.new(environment_name, 'test_path_1')])
    @environment_classes_api.expects(:list_classes).with(environment_name, 42, Proxy::PuppetApi::MAX_PUPPETAPI_TIMEOUT).
      returns(Proxy::PuppetApi::EnvironmentClassesApiv3::NOT_MODIFIED)
    @counter.update_class_counts

    assert_equal 100, @counter.count_classes_in_environment(environment_name)
    _, etag = @counter.etag_cache[environment_name]
    assert_equal 42, etag
    assert_equal({'test_environment' => {:class_count => 100}}, @counter.count_all_classes)
  end
end
