NetServerHandlers = {}

---Handles applying the selected feat for the current player.
---@param _ string The network message channel.
---@param payload any The selected feat.
---@param peerId integer The peer ID of the player.
function NetServerHandlers.SelectedFeatSpecification(_, payload, peerId)
    _E6P("Selected feat information: " .. payload)
    ---@type SelectedFeatPayloadType
    local message = Ext.Json.Parse(payload)
    local entity = Ext.Entity.Get(message.PlayerId)

    ---@type SelectedFeatType[]
    local e6Feats = entity.Vars.E6_Feats
    if e6Feats == nil then
        e6Feats = {}
    end
    table.insert(e6Feats, message.Feat)
    entity.Vars.E6_Feats = e6Feats

    E6_ApplyFeat(message.PlayerId, message.Feat)
end

---Handles applying the selected feat for the current player.
---@param _ string The network message channel.
---@param payload any The selected feat.
---@param peerId integer The peer ID of the player.
function NetServerHandlers.ExportCharacter(_, payload, peerId)
    local entity = Ext.Entity.Get(payload)
    if entity ~= nil then
        E6_ToFile(entity, "E6_Character.json", {"Party", "ServerReplicationDependencyOwner", "InventoryContainer"})
    end
end

---Handles applying the selected feat for the current player.
---@param _ string The network message channel.
---@param payload any The selected feat.
---@param peerId integer The peer ID of the player.
function NetServerHandlers.SetXPPerFeat(_, payload, peerId)
    ---@type SetXPPerFeatPayloadType
    local message = Ext.Json.Parse(payload)
    local entity = Ext.Entity.Get(message.PlayerId)
    if entity ~= nil and type(message.XPPerFeat) == "number" then
        _E6P("Setting XP Per Feat to: " .. tostring(message.XPPerFeat))
        Ext.Vars.GetModVariables(ModuleUUID).E6_XPPerFeat = message.XPPerFeat
        -- We don't want to accumulate the greant feat point and remove feat point statuses ad nauseum.
        -- Reset them when the feat point count changes.
        FeatPointTracker:ResetAll()
    else
        _E6Error("Failed to set XP Per Feat. Got the value: '" .. tostring(message.XPPerFeat) .. "'")
    end
end

return NetServerHandlers
