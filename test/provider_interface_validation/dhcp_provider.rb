module DhcpProviderInterfaceValidation
  def assert_dhcp_provider_interface(dhcp_provider)
    assert dhcp_provider.respond_to?(:load_subnets)
    assert dhcp_provider.respond_to?(:load_subnet_data)
    assert dhcp_provider.respond_to?(:find_subnet)
    assert dhcp_provider.respond_to?(:subnets)
    assert dhcp_provider.respond_to?(:all_hosts)
    assert dhcp_provider.respond_to?(:unused_ip)
    assert dhcp_provider.respond_to?(:find_record)
    assert dhcp_provider.respond_to?(:add_record)
    assert dhcp_provider.respond_to?(:del_record)
  end
end
