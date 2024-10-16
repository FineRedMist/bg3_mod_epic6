SubscribedEvents = {}

local netEventsRegistry = CommandRegistry:new()

netEventsRegistry:register(NetChannels.E6_CLIENT_TO_SERVER_SELECTED_FEAT_SPEC, NetCommand:new(NetServerHandlers.SelectedFeatSpecification))
netEventsRegistry:register(NetChannels.E6_CLIENT_TO_SERVER_EXPORT_CHARACTER, NetCommand:new(NetServerHandlers.ExportCharacter))
netEventsRegistry:register(NetChannels.E6_CLIENT_TO_SERVER_SET_XP_PER_FEAT, NetCommand:new(NetServerHandlers.SetXPPerFeat))
-- Subscribe to events
function SubscribedEvents.SubscribeToEvents()
    RegisterNetListeners(netEventsRegistry)
end

return SubscribedEvents
