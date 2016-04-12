require 'test_helper'
require 'puppet'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/initializer'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/class_scanner_base'
require 'puppet_proxy/puppet_cache'
require 'tmpdir'

module PuppetCacheTestSuite
  def setup
    Proxy::Puppet::Plugin.load_test_settings(:puppet_conf => module_path('puppet.conf'))
    Proxy::Puppet::Initializer.new.reset_puppet
  end

  def test_should_refresh_classes_cache_when_dir_is_not_in_cache
    @scanner.scan_directory(module_path('modules_include'))

    assert_equal Proxy::Puppet::PuppetClass.new('testinclude'),
                 @classes_cache[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')].first
    assert_equal Proxy::Puppet::PuppetClass.new('testinclude::sub::foo', 'param1' => 'first_parameter', 'param2' => 'second_parameter'),
                 @classes_cache[module_path('modules_include'), module_path('modules_include/testinclude/manifests/sub/foo.pp')].first
    assert_equal 2, @classes_cache.values(module_path('modules_include')).size
  end

  def test_should_refresh_timestamps_when_dir_is_not_in_cache
    @scanner.scan_directory(module_path('modules_include'))

    assert @timestamps[module_path('modules_include'), module_path('modules_include/testinclude/manifests/sub/foo.pp')]
    assert @timestamps[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')]
    assert_equal 2, @timestamps.values(module_path('modules_include')).size
  end

  def test_scan_directory_response
    cache = @scanner.scan_directory(module_path('modules_include'))

    assert_kind_of Array, cache
    assert_equal 2, cache.size

    klass = cache.find { |k| k.name == "sub::foo" }
    assert_equal "testinclude", klass.module
    assert_equal "sub::foo", klass.name
    assert_equal({'param1' => 'first_parameter', 'param2' => 'second_parameter'}, klass.params)
    assert cache.find { |k| k.name == "testinclude" }
  end


  def test_should_refresh_cache_when_dir_is_changed
    @classes_cache[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')] =
      [Proxy::Puppet::PuppetClass.new('testinclude'),
       Proxy::Puppet::PuppetClass.new('another_testinclude'),
       Proxy::Puppet::PuppetClass.new('yet_another_testinclude')]
    @timestamps[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')] =
      1000
    assert_equal 3, @classes_cache.values(module_path('modules_include')).size

    @scanner.scan_directory(module_path('modules_include'))

    assert_equal 2, @classes_cache.values(module_path('modules_include')).size
    assert_equal 2, @timestamps.values(module_path('modules_include')).size
    assert @timestamps[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')] != 1000
  end

  def test_should_detect_module_removals
    @classes_cache[module_path('modules_include'), module_path('modules_include/removed_testinclude/manifests/init.pp')] =
      [Proxy::Puppet::PuppetClass.new('testinclude')]
    @timestamps[module_path('modules_include'), module_path('modules_include/removed_testinclude/manifests/init.pp')] =
      Time.now.to_i + 10_000
    assert @classes_cache[module_path('modules_include'), module_path('modules_include/removed_testinclude/manifests/init.pp')]

    @scanner.scan_directory(module_path('modules_include'))

    assert_nil @classes_cache[module_path('modules_include'), module_path('modules_include/removed_testinclude/manifests/init.pp')]
    assert_nil @timestamps[module_path('modules_include'), module_path('modules_include/removed_testinclude/manifests/init.pp')]
    assert @classes_cache[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')]
    assert @classes_cache[module_path('modules_include'), module_path('modules_include/testinclude/manifests/sub/foo.pp')]
  end

  def test_should_not_refresh_cache_when_cache_is_more_recent
    @classes_cache[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')] =
      [Proxy::Puppet::PuppetClass.new('testinclude'),
       Proxy::Puppet::PuppetClass.new('another_testinclude'),
       Proxy::Puppet::PuppetClass.new('yet_another_testinclude')]
    @timestamps[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')] =
      (current_time = Time.now.to_i + 10_000)
    assert_equal 3, @classes_cache.values(module_path('modules_include')).size

    @scanner.scan_directory(module_path('modules_include'))
    assert_equal 4, @classes_cache.values(module_path('modules_include')).size
    assert_equal 2, @timestamps.values(module_path('modules_include')).size
    assert @timestamps[module_path('modules_include'), module_path('modules_include/testinclude/manifests/init.pp')] == current_time
  end

  def test_should_return_no_puppet_classes_when_environment_has_no_modules
    Dir.expects(:glob).with('empty_environment/*').returns([])
    result = @scanner.scan_directory('empty_environment')

    assert result.empty?
  end

  def test_should_parse_puppet_classes_with_unicode_chars
    @scanner.scan_directory(module_path('with_unicode_chars'))
    assert_equal 1,  @classes_cache.values(module_path('with_unicode_chars')).size
  end

  class EnvironmentRetrieverForTesting
    def get(an_environment)
      raise "Unexpected environment name '#{an_environment}'" unless an_environment == 'first'
      ::Proxy::Puppet::Environment.new('first', [File.expand_path('modules_include', File.expand_path('../fixtures', __FILE__))])
    end
  end
  def test_responds_to_classes_in_environment
    @scanner.classes_in_environment('first')
    assert_equal 2, @timestamps.values(File.expand_path('modules_include', File.expand_path('../fixtures', __FILE__))).size
  end

  def module_path(relative_path)
    File.expand_path(relative_path, File.expand_path('../fixtures', __FILE__))
  end
end

if Puppet::PUPPETVERSION < '4.0'
  class CachingRetrieverWithLegacyParserTest < Test::Unit::TestCase
    include PuppetCacheTestSuite

    def setup
      super
      @classes_cache = ::Proxy::MemoryStore.new
      @timestamps = ::Proxy::MemoryStore.new
      @scanner = ::Proxy::Puppet::PuppetCache.new(EnvironmentRetrieverForTesting.new, ::Proxy::Puppet::ClassScanner.new(nil), @classes_cache, @timestamps)
    end
  end
end

if Puppet::PUPPETVERSION > '3.2'
  class CachingRetrieverWithFutureParserTest < Test::Unit::TestCase
    include PuppetCacheTestSuite

    def setup
      super
      @classes_cache = ::Proxy::MemoryStore.new
      @timestamps = ::Proxy::MemoryStore.new
      @scanner = ::Proxy::Puppet::PuppetCache.new(EnvironmentRetrieverForTesting.new, ::Proxy::Puppet::ClassScannerEParser.new(nil), @classes_cache, @timestamps)
    end
  end
end
