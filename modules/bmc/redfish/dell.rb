module RedfishVendorOverridesDellInc
  def powercycle
    # ForceRestart was added in Lifecycle Controller 3.30.30.30
    # prior to that, it required ForceOff followed by On.
    if system.Actions&.[]('#ComputerSystem.Reset')&.[]('ResetType@RedfishAllowableValues')&.include? 'ForceRestart'
      poweraction('ForceRestart')
    else
      poweraction('ForceOff')
      # it only takes a couple seconds to force off, but if you send the 'On' action too
      # quickly, you'll get an error that the server is already on, because it hasn't
      # actually shut off yet. fifteen seconds is chosen arbitrarily; hopefully it covers
      # all scenarios.
      sleep 15
      poweraction('On')
    end
  end

  def reset(type = nil)
    logger.debug("BMC reset arg #{type.inspect} unused for Dell Redfish - GracefulRestart only") if type
    host.post(path: manager.Actions&.[]('#Manager.Reset')&.[]('target'), payload: { 'ResetType' => 'GracefulRestart' })
  end
end
