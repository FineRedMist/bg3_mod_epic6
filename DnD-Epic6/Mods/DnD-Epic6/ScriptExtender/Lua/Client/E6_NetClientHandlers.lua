NetClientHandlers = {}

---checks whether the current player is correct for showing/closing UI.
---@param messageUuid GUIDSTRING The Uuid sent in the message.
---@return boolean Whether the UUID of the host matches that sent in the message.
local function CheckPlayerIsRightHandler(messageUuid)
    local player = GetLocallyControlledCharacter()
    if not player or not player.Uuid then
        return false
    end
    return GetEntityID(player) == messageUuid
end


function NetClientHandlers.ShowFeatSelectorUI(_, payload, peerId)
    ---@type PlayerInformationType
    local message = Ext.Json.Parse(payload)

    if not CheckPlayerIsRightHandler(message.UUID) then
        return
    end

    E6_FeatSelectorUI(message)
end

function NetClientHandlers.CloseUI(_, payload, peerId)
    if not CheckPlayerIsRightHandler(payload) then
        return
    end
    E6_CloseUI()
end

return NetClientHandlers
