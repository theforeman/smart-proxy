require 'json'

module RedfishTestHelper
  ROOT_DATA = {
    "Name" => "Redfish Server Test Mock",
    "Systems" => {
      "@odata.id" => "/redfish/v1/Systems",
    },
    "Managers" => {
      "@odata.id" => "/redfish/v1/Managers",
    },
    "@odata.id" => "/redfish/v1",
  }.freeze

  SYSTEMS_DATA = {
    "@odata.id" => "/redfish/v1/Systems",
    "Members" => [
      { "@odata.id" => "/redfish/v1/Systems/TESTSYSTEM" },
    ],
  }.freeze

  SYSTEM_DATA = {
    "@odata.id" => "/redfish/v1/Systems/TESTSYSTEM",
    "Manufacture" => "Server Vendor",
    "IndicatorLED" => "Off",
    "PowerState" => "On",
    "Boot" => {
      "BootSourceOverrideTarget" => "Pxe",
    },
    "Model" => "TestServer A",
    "SerialNumber" => "AA645",
    "AssetTag" => "ax",
    "Actions" => {
      "#ComputerSystem.Reset" => {
        "target" => "/redfish/v1/Systems/TESTSYSTEM/Actions/ComputerSystem.Reset",
      },
    },
  }.freeze

  # Fixture for systems that support the newer LocationIndicatorActive field
  SYSTEM_DATA_WITH_LOCATION_INDICATOR = SYSTEM_DATA.merge(
    "LocationIndicatorActive" => false
  ).freeze

  def mask_redfish_acceess(protocol: "https", host: "host")
    # root
    stub_request(:get, "#{protocol}://#{host}#{ROOT_DATA['@odata.id']}").
      to_return(status: 200, body: JSON.generate(ROOT_DATA))
    # root.systems
    stub_request(:get, "#{protocol}://#{host}#{SYSTEMS_DATA['@odata.id']}").
      to_return(status: 200, body: JSON.generate(SYSTEMS_DATA))
    # root.system
    stub_request(:get, "#{protocol}://#{host}#{SYSTEM_DATA['@odata.id']}").
      to_return(status: 200, body: JSON.generate(SYSTEM_DATA))
  end
end
