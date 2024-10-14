NetClientHandlers = {}

function NetClientHandlers.ShowFeatSelectorUI(_, payload, peerId)
    ---@type PlayerInformationType
    local message = Ext.Json.Parse(payload)

    E6_FeatSelectorUI(message)
end

return NetClientHandlers
