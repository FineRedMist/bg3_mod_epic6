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

---There are two ways to manipulate the feat points, by the ApplyStatus which lingers forever, or by boosts.
---With boosts, the bost itself disappears from the character on save/load, but the effect remains.
---With passives, the passives stick, making them easier to remove. Using passives (but cleaning up any data)
---from the boost system.
local RemoveFeatPointBoostName = "ActionResource(FeatPoint,-1,0)"
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
    -- Remove any that were granted using boosts.
    for i = 1, E6_GetFeatPointBoostAmount(id) do
        -- We do an add boosts with a negative to subtract the value in the boost.
        -- The boost itself will disappear on save/load, but the change in action points remains.
        Osi.AddBoosts(id, RemoveFeatPointBoostName, "E6_FeatPoints", FeatPointSourceId)
    end
end

---@type table<GUIDSTRING, boolean> The mapping of character ID to whether the character has had their feat points wiped.
local PointsWiped = {}
local function InitialPointWipe(id)
    if not PointsWiped[id] then
        RemoveAllFeatPoints(id)
        local entity = Ext.Entity.Get(id)
        if entity.Vars.E6_Feats then
            E6_VerifyFeats(id, entity.Vars.E6_Feats)
        end
        PointsWiped[id] = true
        return true
    end
    return false
end


---@return number
local function E6_GetLevel6XP()
    local extraData = Ext.Stats.GetStatsManager().ExtraData
    return extraData.Level1 + extraData.Level2 + extraData.Level3 + extraData.Level4 + extraData.Level5
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

---Retrieves the amount of experience required for the character to earn a feat.
---@return number
function FeatPointTracker:GetEpicFeatXP()
    local setting = Ext.Vars.GetModVariables(ModuleUUID).E6_XPPerFeat
    if type(setting) == "number" and setting >= 100 and setting <= 20000 then
        return setting
    end
    return Ext.Stats.GetStatsManager().ExtraData.Epic6FeatXP
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
    local characterGuid = entity.Uuid.EntityUuid
    IsRespecing[characterGuid] = true
    local charName = GetCharacterName(entity, true)

    if entity.Vars.E6_Feats then
        E6_RemoveFeats(characterGuid, entity.Vars.E6_Feats)
    end
end

---Restores feats for a character that cancelled a respec.
function FeatPointTracker:OnRespecCancel(entity)
    local characterGuid = entity.Uuid.EntityUuid
    IsRespecing[characterGuid] = false
    local charName = GetCharacterName(entity, true)

    if entity.Vars.E6_Feats then
        E6_ApplyFeats(characterGuid, entity.Vars.E6_Feats)
    end
end

---I've seen this fire without a start respec on level load. To be sure I don't accidentally
---break a character, check that the respec was started before resetting the character.
function FeatPointTracker:OnRespecComplete(entity)
    local characterGuid = entity.Uuid.EntityUuid
    local wasRespecStarted = IsRespecing[characterGuid]
    IsRespecing[characterGuid] = false
    local charName = GetCharacterName(entity, true)

    if wasRespecStarted then
        self:Reset(entity, true)
    end
end

---Resets the feat points for a specific entity.
---This occurs either after an XP Per Feat change or character respec.
---@param entity EntityHandle The entity for the character.
---@param isRespec boolean Whether the reset is due to a respec.
function FeatPointTracker:Reset(entity, isRespec)
    if entity.Uuid then
        local characterGuid = entity.Uuid.EntityUuid
        local charName = GetCharacterName(entity, true)
        RemoveAllFeatPoints(characterGuid)
        if isRespec then
            Osi.RemovePassive(characterGuid, EpicCharacterPassive)
            Osi.RemoveSpell(characterGuid, EpicSpellContainerName, 0)
            if entity.Vars.E6_Feats then
                entity.Vars.E6_Feats = nil
            end
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
    PendingTickWait[id] = 5
end

---Updates the feat granting spell, removing if if they are not the host or don't have action points, and adding it if they are the host and do have points.
---@param id GUIDSTRING The ID of the character.
---@param charName string The name of the character.
---@param currentFeatPointCount integer The current feat point count for the character.
local function UpdateFeatGrantingSpell(id, charName, currentFeatPointCount)
    local hasSpell = HasFeatGrantingSpell(id)
    --_E6P("Character " .. charName .. " has feat granting spell: " .. tostring(hasSpell) .. ", target feat count: " .. tostring(targetFeatCount))
    -- Allow the host to have the spell to set the initial XP Per Feat value.
    if not hasSpell and (currentFeatPointCount >= 1 or IsHost(id)) then
        --_E6P("Character " .. charName .. ": adding spell " .. EpicSpellContainerName)
        Osi.AddSpell(id, EpicSpellContainerName, 0, 0)
        SetPendingFeatCount(id)
    elseif hasSpell and currentFeatPointCount < 1 and not IsHost(id) then -- Remove the spell if we have no feats to grant.
        --_E6P("Character " .. charName .. ": removing spell " .. EpicSpellContainerName)
        Osi.RemoveSpell(id, EpicSpellContainerName, 0)
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

---Grants or removes the passive for the epic character (when they reach level 6).
---@param id GUIDSTRING The ID of the character.
---@param charName string The name of the character.
---@param level integer The level of the character.
local function UpdateEpicCharacterPassive(id, charName, level)
    local hasPassive = HasPassiveEpicCharacter(id)
    --_E6P("Character " .. charName .. " has feat granting spell: " .. tostring(hasSpell) .. ", target feat count: " .. tostring(targetFeatCount))
    -- Allow the host to have the spell to set the initial XP Per Feat value.
    if not hasPassive and level >= 6 then
        --_E6P("Character " .. charName .. ": adding spell " .. EpicSpellContainerName)
        Osi.AddPassive(id, EpicCharacterPassive)
        SetPendingFeatCount(id)
    elseif hasPassive and level < 6 then -- Remove the spell if we have no feats to grant.
        --_E6P("Character " .. charName .. ": removing spell " .. EpicSpellContainerName)
        Osi.RemovePassive(id, EpicCharacterPassive)
        SetPendingFeatCount(id)
    end
end

local function ShouldWaitForLaterTick(id)
    local pendingWait = PendingTickWait[id]
    if pendingWait then
        pendingWait = pendingWait -1
        PendingTickWait[id] = pendingWait
        if pendingWait > 0 then
            return true
        else
            PendingTickWait[id] = nil
        end
    end
    return false
end

---Evaluates how many feat points an entity should have, based on the experience points per feat.
---It then checks how many points are pending to be applied and verifies that operation is complete
---before applying the feat point adjustments.
-- Only update if:
--  Their experience is at least level 6
--  They have selected all 6 class levels
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

    local id = ent.Uuid.EntityUuid
    
    if IsRespecing[id] then
        return
    end
    
    if ShouldWaitForLaterTick(id) then
        return
    end

    -- Do a one time refresh of the points, as the method to track has changed between versions.
    if InitialPointWipe(id) then
        SetPendingFeatCount(id)
        return
    end

    -- CurrentLevelExperience is the experience from 6 to 7 we have accumulated. 
    -- The XP Data is constructed in such a way that the XP cap is reached before level 7
    -- xp can be earned, so you never really reach level 7.
    local xpToNextLevel = 0
    
    -- If we have enough experience and our level is high enough, compute what our total feat count ought to be.
    if ent.Experience.TotalExperience >= E6_GetLevel6XP() and ent.EocLevel.Level >= 6 then
        xpToNextLevel = ent.Experience.CurrentLevelExperience
    end

    local epic6FeatXP = self:GetEpicFeatXP()
    -- Number of feats and feat points we should have.
    local totalFeatCount = math.floor(xpToNextLevel/epic6FeatXP)

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

    UpdateFeatGrantingSpell(id, charName, targetFeatPointCount)
    UpdateEpicCharacterPassive(id, charName, ent.EocLevel.Level)

    -- If we have caught up from the total feat count expected to the amount granted, we are done.
    -- We can't bring the feat point count below zero, so don't bother.
    if (deltaFeatCount < 0 and currentFeatPointCount == 0) or deltaFeatCount == 0 then
        PendingFeatPoints[id] = nil
    elseif targetFeatPointCount <= 0 then
        -- If we have no feats to grant, we should remove all the feat points.
        --_E6P("Update for " .. charName .. ": removing all points")
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
end

return FeatPointTracker
