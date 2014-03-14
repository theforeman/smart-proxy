require 'test_helper'

class PuppetConfigReaderTest < Test::Unit::TestCase

  def setup
    @puppet_conf = File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', 'puppet.conf'))
  end

  def build
    Proxy::Puppet::ConfigReader.new(@puppet_conf)
  end

  def test_should_initialize
    assert_kind_of Proxy::Puppet::ConfigReader, build
  end

  def test_get_should_return_section_hash
    assert_kind_of Hash, build.get
    assert_equal [:agent, :development, :main, :master, :production], build.get.keys.sort
  end

  def test_get_section_contents_hash
    assert_kind_of Hash, build.get[:production]
    assert_equal [:modulepath], build.get[:production].keys
    assert_equal '/etc/puppet/modules/production:/etc/puppet/modules/common', build.get[:production][:modulepath]
  end

end
