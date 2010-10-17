require 'test/unit'
require 'dhcp'
require 'dhcp/server/ms'

class DHCPServerMicrosoftTest < Test::Unit::TestCase

  def setup
    username = "domain\\username"
    password = File.read("lib/.pass").chomp
    gateway  = "gateway"
    dhcpSrv  = "server"

    #UGLY workaround for now
    @server = @@server ||= DHCP::Server::MS.new({:username => username, :password => password,
                                                :gateway => gateway, :server => dhcpSrv})
  end

  def find_subnet
    @subnet = @server.find_subnet "172.20.76.0"
  end

  def test_it_should_get_subnets_data
    assert @server.subnets.size > 0
  end

    def test_should_load_subnet_records
    find_subnet
    @server.loadSubnetData @subnet
    assert @subnet.records.size > 0
  end

  def test_subnet_should_have_options
    find_subnet
    @server.loadSubnetOptions @subnet
    assert @subnet.options.size > 0
  end

  def test_subnet_should_have_options_and_values
    find_subnet
    @server.loadSubnetOptions @subnet
    error = false
    @subnet.options.each do |o,v|
      error = true if o.nil? or o.empty? or v.nil? or o.empty?
    end
    assert error == false
  end

  def test_records_should_have_options
    find_subnet
    @server.loadSubnetData @subnet
    record = @subnet.records.first
    @server.loadRecordOptions record
    assert record.options.size > 0
  end

  def test_records_should_have_options_and_values
    find_subnet
    @server.loadSubnetData @subnet
    record = @subnet.records.first
    @server.loadRecordOptions record
    error = false
    record.options.each { |o,v| error = true if o.nil? or o.empty? or v.nil? or v.empty? }
    assert error == false
  end

  def test_should_find_unused_ip
    find_subnet
    ip = @subnet.unused_ip
    assert ip =! nil
  end

end
