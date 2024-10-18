NetClientHandlers = {}

function NetClientHandlers.ShowFeatSelectorUI(_, payload, peerId)
    ---@type PlayerInformationType
    local message = Ext.Json.Parse(payload)

    E6_FeatSelectorUI(message)
end

function NetClientHandlers.CloseUI(_, payload, peerId)
    E6_CloseUI()
end

return NetClientHandlers
