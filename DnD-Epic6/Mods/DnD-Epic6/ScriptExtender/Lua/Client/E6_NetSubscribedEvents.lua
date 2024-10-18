SubscribedEvents = {}

local netEventsRegistry = CommandRegistry:new()

netEventsRegistry:register(NetChannels.E6_SERVER_TO_CLIENT_SHOW_FEAT_SELECTOR, NetCommand:new(NetClientHandlers.ShowFeatSelectorUI))
netEventsRegistry:register(NetChannels.E6_SERVER_TO_CLIENT_CLOSE_UI, NetCommand:new(NetClientHandlers.CloseUI))

-- Subscribe to events
function SubscribedEvents.SubscribeToEvents()
    RegisterNetListeners(netEventsRegistry)
end

return SubscribedEvents
