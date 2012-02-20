require 'test/test_helper'

class PuppetClassTest < Test::Unit::TestCase

  def test_should_have_a_logger
    assert_respond_to Proxy::Puppet, :logger
  end

  def test_puppet_class_should_be_an_opject
    klass = Proxy::Puppet::PuppetClass.new :name => "install", :module => "foreman_proxy"
    assert_kind_of Proxy::Puppet::PuppetClass, klass
  end

  def test_should_find_class_in_a_manifest
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'

    EOF
    klasses =  Proxy::Puppet::PuppetClass.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size

    klass = klasses.first

    assert_equal "install", klass.name
    assert_equal "foreman", klass.module
  end

  def test_should_not_file_a_class
    manifest = <<-EOF
      include 'x::y'
    EOF
    klasses =  Proxy::Puppet::PuppetClass.scan_manifest(manifest)
    assert klasses.empty?
  end
    def test_should_find_multiple_class_in_a_manifest
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    class foreman::params {
      $var = 'xyz'
    }

    EOF
    klasses =  Proxy::Puppet::PuppetClass.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 2, klasses.size

    klass = klasses.last

    assert_equal "params", klass.name
    assert_equal "foreman", klass.module
    end

  def test_should_scan_a_dir
    klasses =  Proxy::Puppet::PuppetClass.scan_directory('/tmp/no_such_dir')
    assert_kind_of Array, klasses
    assert klasses.empty?
  end

  #TODO add scans to a real puppet directory with modules

end
