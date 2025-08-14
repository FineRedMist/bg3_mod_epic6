--- @class FeatPointTracker A double-ended queue.
---Maps the entity id to an object that tracks the last known feat count and the granted feat count.
FeatPointTracker = {}
FeatPointTracker.__index = FeatPointTracker

---@class CharacterFeatPoints The current tracking of adjusting feat points for a character.
---@field LastCount integer The next target total for the feat points.
---@field Pending integer The number of feat points pending to be granted.

---@type table<GUIDSTRING, boolean> The mapping of character ID to character point tracker.
local IsRespecing = {}
---@type table<GUIDSTRING, CharacterFeatPoints> The mapping of character ID to how many feat points the character is expected to have been granted.
local PendingFeatPoints = {}
---@type table<GUIDSTRING, integer> The mapping of character ID to tick wait to test pending points are granted.
local PendingTickWait = {}

local DefaultPendingTickWait = 10
local EpicCharacterPassive = "E6_Epic_EpicCharacter_Passive"
local FeatPointSourceId = "623a5c6f-71eb-46be-b253-8bc977faece9"

---Adds a feat point for the character
---@param id GUIDSTRING
local function AddFeatPoint(id)
    Osi.ApplyStatus(id, "E6_FEAT_GRANTFEATPOINT", -1, -1, FeatPointSourceId)
end

---Removes a feat point for the character
---@param id GUIDSTRING
local function RemoveFeatPoint(id)
    Osi.ApplyStatus(id, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, FeatPointSourceId)
end

---Adjusts the feat points for the character by amount (negative or positive).
---@param id GUIDSTRING
---@param amount integer
local function AdjustFeatPoints(id, amount)
    for i = 1, amount do
        AddFeatPoint(id)
    end
    for i = 1, -amount do
        RemoveFeatPoint(id)
    end
end

---Removes all feat points for the character.
---@param id GUIDSTRING
local function RemoveAllFeatPoints(id)
    -- We can do both paths without an issue.
    Osi.RemoveStatus(id, "E6_FEAT_GRANTFEATPOINT", FeatPointSourceId)
    Osi.RemoveStatus(id, "E6_FEAT_CONSUMEFEATPOINT", FeatPointSourceId)
    -- We used to use the character id as the source, make sure any lingering points from that are removed, too.
    Osi.RemoveStatus(id, "E6_FEAT_GRANTFEATPOINT", id)
    Osi.RemoveStatus(id, "E6_FEAT_CONSUMEFEATPOINT", id)
end

---@type table<GUIDSTRING, boolean> The mapping of character ID to whether the character has had their feat points wiped.
local CharacterInitiated = {}
---comment
---@param id any
---@return boolean Whether a wait is required for feat points to kick in.
local function InitiateCharacter(id)
    if not CharacterInitiated[id] then
        --RemoveAllFeatPoints(id)
        local entity = Ext.Entity.Get(id)
        E6_VerifyFeats(id, entity.Vars.E6_Feats)
        CharacterInitiated[id] = true
        return true
    end
    return false
end

---Returns the number of feat points granted to the character.
---@param uuid GUIDSTRING The character ID.
---@return number The number of feat points the character has (may be negative)
function E6_GetFeatPointBoostAmount(uuid)
    local result = Osi.GetActionResourceValuePersonal(uuid, "FeatPoint", 0)
    if not result then
        return 0
    end
    return result
end

---Returns the number of feats selected for Epic 6 (does not include feats for actual levels)
---@param entity EntityHandle
---@return integer
local function E6_GetUsedFeatCount(entity)
    local e6Feats = entity.Vars.E6_Feats
    if e6Feats == nil then
        return 0
    end
    return #e6Feats
end

---Creates a new double-ended queue.
---@return FeatPointTracker The double ended queue.
function FeatPointTracker:new()
    local instance = setmetatable({}, self)
    return instance
end

---Resets all the feat points for all entities.
---This occurs when the experience points per feat is changed.
function FeatPointTracker:ResetAll()
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("Experience")) do
        self:Reset(entity, false)
    end
end

---When respecing a character, we need to track that the respec is in progress, and remove all the 
---feats from the character so that they don't interfere with the respec process.
function FeatPointTracker:OnRespecBegin(entity)
    local characterGuid = GetEntityID(entity)
    if not characterGuid then
        local characterName = GetCharacterName(entity, true)
        if characterName == nil then
            _E6Warn("OnRespecBegin: Failed to get the character name for the player.")
        else
            _E6Warn("OnRespecBegin: Failed to get the character GUID for the player: " .. characterName)
        end
        return
    end
    IsRespecing[characterGuid] = true

    E6_RemoveFeats(characterGuid, entity.Vars.E6_Feats)
end

---Restores feats for a character that cancelled a respec.
function FeatPointTracker:OnRespecCancel(entity)
    local characterGuid = GetEntityID(entity)
    if not characterGuid then
        local characterName = GetCharacterName(entity, true)
        if characterName == nil then
            _E6Warn("OnRespecCancel: Failed to get the character name for the player.")
        else
            _E6Warn("OnRespecCancel: Failed to get the character GUID for the player: " .. characterName)
        end
        return
    end
    IsRespecing[characterGuid] = false

    if entity.Vars.E6_Feats then
        E6_ApplyFeats(characterGuid, entity.Vars.E6_Feats)
    end
end

---I've seen this fire without a start respec on level load. To be sure I don't accidentally
---break a character, check that the respec was started before resetting the character.
function FeatPointTracker:OnRespecComplete(entity)
    local characterGuid = GetEntityID(entity)
    if not characterGuid then
        local characterName = GetCharacterName(entity, true)
        if characterName == nil then
            _E6Warn("OnRespecComplete: Failed to get the character name for the player.")
        else
            _E6Warn("OnRespecComplete: Failed to get the character GUID for the player: " .. characterName)
        end
        return
    end
    local wasRespecStarted = IsRespecing[characterGuid]
    IsRespecing[characterGuid] = false

    if wasRespecStarted then
        self:Reset(entity, true)
    end
end

---Resets the feat points for a specific entity.
---This occurs either after an XP Per Feat change or character respec.
---@param entity EntityHandle The entity for the character.
---@param isRespec boolean Whether the reset is due to a respec.
function FeatPointTracker:Reset(entity, isRespec)
    local characterGuid = GetEntityID(entity)
    if not characterGuid then
        local characterName = GetCharacterName(entity, true)
        if characterName == nil then
            _E6Warn("Reset: Failed to get the character name for the player.")
        else
            _E6Warn("Reset: Failed to get the character GUID for the player: " .. characterName)
        end
        return
    end

    RemoveAllFeatPoints(characterGuid)
    if isRespec then
        Osi.RemovePassive(characterGuid, EpicCharacterPassive)
        Osi.RemoveSpell(characterGuid, EpicSpellContainerName, 0)
        if entity.Vars.E6_Feats then
            entity.Vars.E6_Feats = nil
        end
    end
end

---Determines if the character has the feat granting spell.
---@param id GUIDSTRING The ID of the character.
---@return boolean Whether the character has the feat granting spell.
local function HasFeatGrantingSpell(id)
    local hasSpell = Osi.HasSpell(id, EpicSpellContainerName)
    if not hasSpell or hasSpell == 0 then
        return false
    end
    return true
end

---Sets a waiting period before doing subsequent updates.
---@param id GUIDSTRING The ID of the character.
---@param val CharacterFeatPoints? Optional new value for feat point modifications.
local function SetPendingFeatCount(id, val)
    PendingFeatPoints[id] = val
    PendingTickWait[id] = DefaultPendingTickWait
end

---Ensure the player has the feat granting spell.
---@param id GUIDSTRING The ID of the character.
local function UpdateFeatGrantingSpell(id)
    local hasSpell = HasFeatGrantingSpell(id)
    -- Allow the host to have the spell to set the initial XP Per Feat value.
    if not hasSpell then
        Osi.AddSpell(id, EpicSpellContainerName, 0, 0)
        SetPendingFeatCount(id)
    end
end

---Whether the character has the passive for the epic character.
---@param id GUIDSTRING The ID of the character.
---@return boolean Whether the character has the passive for the epic character.
local function HasPassiveEpicCharacter(id)
    local hasPassive = Osi.HasPassive(id, EpicCharacterPassive)
    if not hasPassive or hasPassive == 0 then
        return false
    end
    return true
end

---Grants or removes the passive for the epic character (when they reach maximum level).
---@param id GUIDSTRING The ID of the character.
---@param charName string The name of the character.
---@param level integer The level of the character.
local function UpdateEpicCharacterPassive(id, charName, level)
    local hasPassive = HasPassiveEpicCharacter(id)
    -- Allow the host to have the spell to set the initial XP Per Feat value.
    if not hasPassive and level >= E6_GetMaxLevel() then
        Osi.AddPassive(id, EpicCharacterPassive)
        SetPendingFeatCount(id)
    elseif hasPassive and level < E6_GetMaxLevel() then -- Remove the spell if we have no feats to grant.
        Osi.RemovePassive(id, EpicCharacterPassive)
        SetPendingFeatCount(id)
    end
end

---Determines if there is a pending tick wait for the character.
---@param id GUIDSTRING The id of the character
---@return boolean Whether there is a pending tick wait for the character.
local function HasPendingTickWait(id)
    return PendingTickWait[id] ~= nil
end

---Determines whether the tick loop should wait for the next tick to process the feat points. Decrements the tick counter.
---@param id GUIDSTRING The id of the character
---@return boolean Whether to wait for a subsequent tick
local function ShouldWaitForLaterTick(id)
    local pendingWait = PendingTickWait[id]
    if pendingWait then
        pendingWait = pendingWait - 1
        PendingTickWait[id] = pendingWait
        if pendingWait > 0 then
            return true
        else
            PendingTickWait[id] = nil
        end
    end
    return false
end

---@type table<GUIDSTRING, function[]> Callbacks to call for the character when the feat points are stable. Once called, removed. Passes the character ID to the function.
local onStableCallbacks = {}

---Adds a callback to be called when the character is stable pointwise.
function FeatPointTracker:OnStableCallback(id, callback)
    if not onStableCallbacks[id] then
        onStableCallbacks[id] = {}
    end
    table.insert(onStableCallbacks[id], callback)
end

---Calls the callbacks now that the character is stable pointwise.
---@param id GUIDSTRING
local function CallOnStableCallbacks(id)
    local callbacks = onStableCallbacks[id]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            callback(id)
        end
        onStableCallbacks[id] = nil
    end
end

---Evaluates how many feat points an entity should have, based on the experience points per feat.
---It then checks how many points are pending to be applied and verifies that operation is complete
---before applying the feat point adjustments.
-- Only update if:
--  Their experience is at least maximum level
--  They have selected all available class levels
--  They have enough experience to warrant feats.
---@param ent EntityHandle The entity for the character.
function FeatPointTracker:Update(ent)
    local charName = GetCharacterName(ent, true)
    if not charName then
        return
    end

    if not ent.Experience or not ent.EocLevel then
        return
    end

    local id = GetEntityID(ent)
    if not id then
        _E6Warn("Update: Failed to get the character GUID for the player: " .. charName)
        return
    end
    
    if IsRespecing[id] then
        return
    end
    
    if ShouldWaitForLaterTick(id) then
        return
    end

    -- Do a one time refresh of the points, as the method to track has changed between versions.
    if InitiateCharacter(id) then
        SetPendingFeatCount(id)
        return
    end

    -- If we load from a save game, then we have to apply boosts to the character before we skip any
    -- further processing related to combat.
    if ent.Vars.E6_InCombat then
        return
    end

    -- CurrentLevelExperience is the experience from max level to an unreachable level we have accumulated (for example 6 to 7 for epic 6).
    -- The XP Data is constructed in such a way that the XP cap is reached before the unreachable level.
    -- xp can be earned, so you never really reach that level.
    local xpToNextLevel = 0
    
    -- If we have enough experience and our level is high enough, compute what our total feat count ought to be.
    if ent.Experience.TotalExperience >= E6_GetMaxLevelXP() and ent.EocLevel.Level >= E6_GetMaxLevel() then
        xpToNextLevel = ent.Experience.CurrentLevelExperience
    end

    -- Number of feats and feat points we should have.
    local totalFeatCount = GetFeatCountForXP(xpToNextLevel)

    -- Number of feat points used in feats.
    local usedFeatCount = E6_GetUsedFeatCount(ent)
    -- Number of reat points we have.
    local currentFeatPointCount = E6_GetFeatPointBoostAmount(id)
    local currentFeatCount = currentFeatPointCount + usedFeatCount
    local deltaFeatCount = totalFeatCount - currentFeatCount
    local targetFeatPointCount = currentFeatPointCount + deltaFeatCount
    if targetFeatPointCount < 0 then
        targetFeatPointCount = 0
    end

    UpdateFeatGrantingSpell(id)
    UpdateEpicCharacterPassive(id, charName, ent.EocLevel.Level)

    -- If we have caught up from the total feat count expected to the amount granted, we are done.
    -- We can't bring the feat point count below zero, so don't bother.
    if (deltaFeatCount < 0 and currentFeatPointCount == 0) or deltaFeatCount == 0 then
        PendingFeatPoints[id] = nil
    elseif targetFeatPointCount <= 0 then
        -- If we have no feats to grant, we should remove all the feat points.
        RemoveAllFeatPoints(id)
        SetPendingFeatCount(id)
    else
        local pending = 0
        if PendingFeatPoints[id] then
            pending = PendingFeatPoints[id].Pending
            -- If we got the expected amount of feat points (or something odd happened), then reset the pending count.
            if currentFeatPointCount ~= PendingFeatPoints[id].LastCount then
                pending = 0
            end
            -- Otherwise, we assume the previous grant was still pending, and just do some of the remaining amount.
            PendingFeatPoints[id] = nil
        end

        -- Only grant half the remaining feats per tick.
        local difference = deltaFeatCount - pending
        local toAdjust = math.ceil(difference / 2)
        if -0.75 < toAdjust and toAdjust < 0.75 then
            toAdjust = difference
        end

        if toAdjust ~= 0 then
            --_E6P("Update for " .. charName .. ": TargetFeatCount: " .. tostring(totalFeatCount) .. ", UsedFeatCount: " .. tostring(usedFeatCount) .. ", CurrentFeatPointCount: " .. tostring(currentFeatPointCount) .. ", DeltaFeatPointCount: " .. tostring(deltaFeatCount) .. ", adjusting by: " .. tostring(toAdjust))

            AdjustFeatPoints(id, toAdjust)
            SetPendingFeatCount(id, {LastCount = currentFeatPointCount, Pending = toAdjust})
        end
    end

    if not HasPendingTickWait(id) then
        CallOnStableCallbacks(id)
    end
end

return FeatPointTracker
