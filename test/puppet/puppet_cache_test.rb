require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/puppet_cache'
require 'tmpdir'

class PuppetCacheTest < Test::Unit::TestCase

  def setup
    @classes_cache = ::Proxy::MemoryStore.new
    @timestamps = ::Proxy::MemoryStore.new
    @scanner = ::Proxy::Puppet::PuppetCache.new(::Proxy::Puppet::ClassScanner, @classes_cache, @timestamps)
  end

  def test_should_refresh_classes_cache_when_dir_is_not_in_cache
    @scanner.scan_directory('./test/fixtures/modules_include', 'example_env')

    assert_equal Proxy::Puppet::PuppetClass.new('testinclude'),
                 @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp'].first
    assert_equal Proxy::Puppet::PuppetClass.new('testinclude::sub::foo', 'param1' => 'first_parameter', 'param2' => 'second_parameter'),
                 @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/sub/foo.pp'].first
    assert_equal 2, @classes_cache.values('./test/fixtures/modules_include').size
  end

  def test_should_refresh_timestamps_when_dir_is_not_in_cache
    @scanner.scan_directory('./test/fixtures/modules_include', 'example_env')

    assert @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/sub/foo.pp']
    assert @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp']
    assert_equal 2, @timestamps.values('./test/fixtures/modules_include').size
  end

  def test_scan_directory_response
    cache = @scanner.scan_directory('./test/fixtures/modules_include', 'example_env')

    assert_kind_of Array, cache
    assert_equal 2, cache.size

    klass = cache.find { |k| k.name == "sub::foo" }
    assert_equal "testinclude", klass.module
    assert_equal "sub::foo", klass.name
    assert_equal({'param1' => 'first_parameter', 'param2' => 'second_parameter'}, klass.params)
    assert cache.find { |k| k.name == "testinclude" }
  end


  def test_should_refresh_cache_when_dir_is_changed
    @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp'] =
        [Proxy::Puppet::PuppetClass.new('testinclude'),
         Proxy::Puppet::PuppetClass.new('another_testinclude'),
         Proxy::Puppet::PuppetClass.new('yet_another_testinclude')]
    @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp'] =
      1000
    assert_equal 3, @classes_cache.values('./test/fixtures/modules_include').size

    @scanner.scan_directory('./test/fixtures/modules_include', 'example_env')

    assert_equal 2, @classes_cache.values('./test/fixtures/modules_include').size
    assert_equal 2, @timestamps.values('./test/fixtures/modules_include').size
    assert @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp'] != 1000
  end

  def test_should_detect_module_removals
    @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/removed_testinclude/manifests/init.pp'] =
        [Proxy::Puppet::PuppetClass.new('testinclude')]
    @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/removed_testinclude/manifests/init.pp'] =
        Time.now.to_i + 10_000
    assert @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/removed_testinclude/manifests/init.pp']

    @scanner.scan_directory('./test/fixtures/modules_include', 'example_env')

    assert_nil @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/removed_testinclude/manifests/init.pp']
    assert_nil @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/removed_testinclude/manifests/init.pp']
    assert @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp']
    assert @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/sub/foo.pp']
  end

  def test_should_not_refresh_cache_when_cache_is_more_recent
    @classes_cache['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp'] =
        [Proxy::Puppet::PuppetClass.new('testinclude'),
         Proxy::Puppet::PuppetClass.new('another_testinclude'),
         Proxy::Puppet::PuppetClass.new('yet_another_testinclude')]
    @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp'] =
        (current_time = Time.now.to_i + 10_000)
    assert_equal 3, @classes_cache.values('./test/fixtures/modules_include').size

    @scanner.scan_directory('./test/fixtures/modules_include', 'example_env')
    assert_equal 4, @classes_cache.values('./test/fixtures/modules_include').size
    assert_equal 2, @timestamps.values('./test/fixtures/modules_include').size
    assert @timestamps['./test/fixtures/modules_include', './test/fixtures/modules_include/testinclude/manifests/init.pp'] == current_time
  end

  def test_should_return_no_puppet_classes_when_environment_has_no_modules
    Dir.expects(:glob).with('empty_environment/*').returns([])
    result = @scanner.scan_directory('empty_environment', 'example_env')

    assert result.empty?
  end
end
