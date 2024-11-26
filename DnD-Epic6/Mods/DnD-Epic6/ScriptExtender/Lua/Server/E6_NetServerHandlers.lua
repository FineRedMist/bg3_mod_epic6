NetServerHandlers = {}

---Handles applying the selected feat for the current player.
---@param _ string The network message channel.
---@param payload any The selected feat.
---@param peerId integer The peer ID of the player.
function NetServerHandlers.SelectedFeatSpecification(_, payload, peerId)
    ---@type SelectedFeatPayloadType
    local message = Ext.Json.Parse(payload)
    local entity = Ext.Entity.Get(message.PlayerId)

    local characterGuid = GetEntityID(entity)
    if not characterGuid then
        _E6Error("SelectedFeatSpecification: Failed to get the character GUID for the player.")
        return
    end

    ---@type SelectedFeatType[]
    local e6Feats = entity.Vars.E6_Feats
    if e6Feats == nil then
        e6Feats = {}
    end
    table.insert(e6Feats, message.Feat)
    entity.Vars.E6_Feats = e6Feats

    -- If we will have more feat points after applying the feat, then send a message to restore the UI.
    local restoreFeatSelectorUI = E6_GetFeatPointBoostAmount(message.PlayerId) > 1

    E6_ApplyFeat(message.PlayerId, message.Feat)

    if restoreFeatSelectorUI then
        FeatPointTracker:OnStableCallback(characterGuid, OnEpic6FeatSelectorSpell)
    end
end

---Handles applying the selected feat for the current player.
---@param _ string The network message channel.
---@param payload any The selected feat.
---@param peerId integer The peer ID of the player.
function NetServerHandlers.ExportCharacter(_, payload, peerId)
    local entity = Ext.Entity.Get(payload)
    if entity ~= nil then
        --local datePrefix = os.date("%Y-%m-%d")
        local character = GetCharacterName(entity)
        E6_ToFile(entity, character .. "-Export.json", {"Party", "ServerReplicationDependencyOwner", "InventoryContainer", "ServerRecruitedBy"})
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

---Trigger sending an updated feat list from the server to the client on switching.
---@param _ string The network message channel
---@param payload string The character ID to switch to
---@param peerId integer The peer ID of the player.
function NetServerHandlers.SwitchCharacter(_, payload, peerId)
    local entity = Ext.Entity.Get(payload)
    if entity ~= nil then
        OnEpic6FeatSelectorSpell(payload)
    else
        _E6Error("Failed find the character '" .. payload .. "' to switch to.")
    end
end

---Reset the feats and feat points for the given character.
---@param _ string The network message channel
---@param payload string The character ID to switch to
---@param peerId integer The peer ID of the player.
function NetServerHandlers.ResetFeats(_, payload, peerId)
    local entity = Ext.Entity.Get(payload)
    if entity ~= nil then
        E6_RemoveFeats(payload, entity.Vars.E6_Feats)
        entity.Vars.E6_Feats = nil
        FeatPointTracker:OnStableCallback(payload, OnEpic6FeatSelectorSpell)
    else
        _E6Error("Failed find the character '" .. payload .. "' to reset the feats for.")
    end
end

return NetServerHandlers
