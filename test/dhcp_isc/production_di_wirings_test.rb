require 'test_helper'
require 'tempfile'
require 'dhcp_common/subnet_service'
require 'dhcp_common/isc/omapi_provider'
require 'dhcp_isc/isc_state_changes_observer'
require 'dhcp_isc/configuration_loader'

class IscDhcpProductionDiWiringsTest < Test::Unit::TestCase
  def setup
    @settings = {:server => "a_server", :omapi_port => 7911, :key_name => "key_name", :key_secret => "key_secret",
                 :subnets => ["192.168.0.0/255.255.255.0"], :leases_file_observer => :inotify_leases_file_observer,
                 :config => Tempfile.new('config').path, :leases => Tempfile.new('leases').path}
    @container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::DHCP::ISC::PluginConfiguration.new.load_dependency_injection_wirings(@container, @settings)
  end

  def test_provider_initialization
    provider = @container.get_dependency(:dhcp_provider)

    assert_equal @settings[:server], provider.name
    assert_equal @settings[:omapi_port], provider.omapi_port
    assert_equal @settings[:key_name], provider.key_name
    assert_equal @settings[:key_secret], provider.key_secret
    assert_equal Set.new(@settings[:subnets]), provider.managed_subnets
    assert_equal ::Proxy::DHCP::SubnetService, provider.service.class
  end

  def test_state_changes_observer_initialization
    state_observer = @container.get_dependency(:state_changes_observer)
    assert state_observer.service
    assert state_observer.service_initializer
    assert_equal @settings[:leases], state_observer.leases_file_path
    assert_equal @settings[:config], state_observer.config_file_path
  end

  def test_service_initializer_initialization
    initializer = @container.get_dependency(:service_initialization)
    assert initializer.subnet_service
    assert initializer.parser
  end

  def test_parser_initialization
    assert @container.get_dependency(:parser)
  end

  def test_inotify_leases_file_observer_initialization
    leases_observer = @container.get_dependency(:leases_observer)
    assert_equal @settings[:leases], leases_observer.leases_filename
  end
end
