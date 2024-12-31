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
function NetServerHandlers.SetXPPerFeat(_, payload, peerId)
    ---@type SetXPPerFeatPayloadType
    local message = Ext.Json.Parse(payload)
    local entity = Ext.Entity.Get(message.PlayerId)
    if entity == nil then
        _E6Error("Failed to get the entity for the id:" .. message.PlayerId)
        return
    end
    if type(message.XPPerFeat) == "number" then
        _E6P("Setting XP Per Feat to: " .. tostring(message.XPPerFeat))
        Ext.Vars.GetModVariables(ModuleUUID).E6_XPPerFeat = message.XPPerFeat
        -- We don't want to accumulate the greant feat point and remove feat point statuses ad nauseum.
        -- Reset them when the feat point count changes.
        FeatPointTracker:ResetAll()
    else
        _E6Error("Failed to set XP Per Feat. Got the value: '" .. tostring(message.XPPerFeat) .. "'")
    end
    if type(message.XPPerFeatIncrease) == "number" then
        _E6P("Setting XP Per Feat Increase to: " .. tostring(message.XPPerFeatIncrease))
        Ext.Vars.GetModVariables(ModuleUUID).E6_XPPerFeatIncrease = message.XPPerFeatIncrease
        -- We don't want to accumulate the greant feat point and remove feat point statuses ad nauseum.
        -- Reset them when the feat point count changes.
        FeatPointTracker:ResetAll()
    else
        _E6Error("Failed to set XP Per Feat Increase. Got the value: '" .. tostring(message.XPPerFeatIncrease) .. "'")
    end
    FeatPointTracker:OnStableCallback(message.PlayerId, OnEpic6FeatSelectorSpell)
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
        FeatPointTracker:OnStableCallback(GetEntityID(entity), OnEpic6FeatSelectorSpell)
    else
        _E6Error("Failed find the character '" .. payload .. "' to reset the feats for.")
    end
end

local player_uuid = {
    S_Player_Jaheira = "91b6b200-7d00-4d62-8dc9-99e8339dfa1a",
    S_Player_Minsc = "0de603c5-42e2-4811-9dad-f652de080eba"
}
local function SetAvailableLevel(id, level)
    local entity = Ext.Entity.Get(player_uuid[id])
    if entity == nil then
        _E6Error("Failed to get the entity.")
        return
    end

    if not entity.AvailableLevel or not entity.AvailableLevel.Level then
        _E6Error("Failed to get the entity's AvailableLevel.'")
        return
    end

    _E6P("Setting the available level for " .. id .. " from " .. tostring(entity.AvailableLevel.Level) .. " to " .. tostring(level))
    entity.AvailableLevel.Level = level

    if not entity.ServerCharacter or not entity.ServerCharacter.Template or not entity.ServerCharacter.Template.LevelOverride then
        _E6Error("Failed to get the entity's ServerCharacter.LevelOverride.")
        return
    end

    _E6P("Setting the level override for " .. id .. " from " .. tostring(entity.ServerCharacter.Template.LevelOverride) .. " to " .. tostring(level))
    entity.ServerCharacter.Template.LevelOverride = level
end

local function GetAvailableLevel(id)
    local entity = Ext.Entity.Get(player_uuid[id])
    if not entity then
        return -1, -1
    end
    if not entity.AvailableLevel or not entity.AvailableLevel.Level then
        return -1, -1
    end
    if not entity.ServerCharacter or not entity.ServerCharacter.Template or not entity.ServerCharacter.Template.LevelOverride then
        _E6Error("Failed to get the entity's ServerCharacter.LevelOverride.")
        return entity.AvailableLevel.Level, -1
    end
    return entity.AvailableLevel.Level, entity.ServerCharacter.Template.LevelOverride
end

local function TestLevels(id)
    SetAvailableLevel("S_Player_Jaheira", 6)
    local available, templateOverride = GetAvailableLevel("S_Player_Jaheira")
    if available ~= 6 then
        _E6Error("Failed to set the available level for " .. id)
    end
    if templateOverride ~= 6 then
        _E6Error("Failed to set the template level override for " .. id)
    end
end


function NetServerHandlers.RunTest(_, payload, peerId)
    _E6P("Running test: " .. payload)

    -- Try to get Jaheira and set her AvailableLevel directly.
    -- Then test by retrieving it again and seeing what the value is.
    --TestLevels("S_Player_Jaheira")

    -- Repeat for Minsc
    --TestLevels("S_Player_Minsc")
end

return NetServerHandlers
