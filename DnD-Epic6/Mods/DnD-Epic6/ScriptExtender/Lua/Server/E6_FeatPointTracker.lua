--- @class FeatPointTracker A double-ended queue.
---Maps the entity id to an object that tracks the last known feat count and the granted feat count.
FeatPointTracker = {}
FeatPointTracker.__index = FeatPointTracker

---Tracks the feat points on a per character basis.
---@class CharacterPointTracker
---@field Granted integer The total number of feat points granted
---@field Pending integer The number of feat points pending to be applied
---@field RespecStarted boolean Whether the character is in the process of being respecified.

---@type table<GUIDSTRING, CharacterPointTracker> The mapping of character ID to character point tracker.
local actionResourceTracker = {}

---@return number
local function E6_GetLevel6XP()
    local extraData = Ext.Stats.GetStatsManager().ExtraData
    return extraData.Level1 + extraData.Level2 + extraData.Level3 + extraData.Level4 + extraData.Level5
end

---Returns the number of feat points granted to the character.
---@param uuid GUIDSTRING The character ID.
---@return number The number of feat points the character has (may be negative)
local function E6_GetFeatPointBoostAmount(uuid)
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

---Returns the character tracker, creating it if it isn't already present.
---@param characterGuid GUIDSTRING The character ID.
---@return CharacterPointTracker The tracker for the character.
local function GetCharacterTracker(characterGuid)
    if actionResourceTracker[characterGuid] == nil then
        actionResourceTracker[characterGuid] = {Granted = 0, Pending = 0, RespecStarted = false}
    end
    return actionResourceTracker[characterGuid]
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

function FeatPointTracker:OnRespecBegin(entity)
    local characterGuid = entity.Uuid.EntityUuid
    local tracker = GetCharacterTracker(characterGuid)
    tracker.RespecStarted = true
    local charName = GetCharacterName(entity, true)
    _E6P("Respec for " .. charName .. " started.")
end

function FeatPointTracker:OnRespecCancel(entity)
    local characterGuid = entity.Uuid.EntityUuid
    local tracker = GetCharacterTracker(characterGuid)
    tracker.RespecStarted = false
    local charName = GetCharacterName(entity, true)
    _E6P("Respec for " .. charName .. " cancelled.")
end

function FeatPointTracker:OnRespecComplete(entity)
    local characterGuid = entity.Uuid.EntityUuid
    local tracker = GetCharacterTracker(characterGuid)
    local wasRespecStarted = tracker.RespecStarted
    tracker.RespecStarted = false
    local charName = GetCharacterName(entity, true)

    _E6P("Respec for " .. charName .. " complete: wasRespecStarted=" .. tostring(wasRespecStarted))

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

        if isRespec then
            Osi.RemoveSpell(characterGuid, EpicSpellContainerName, 0)
            if entity.Vars.E6_Feats then
                entity.Vars.E6_Feats = nil
            end
        end

        local currentFeatPointCount = E6_GetFeatPointBoostAmount(characterGuid)

        Osi.RemoveStatus(characterGuid, "E6_FEAT_GRANTFEATPOINT", characterGuid)
        Osi.RemoveStatus(characterGuid, "E6_FEAT_CONSUMEFEATPOINT", characterGuid)

        local tracker = GetCharacterTracker(characterGuid)

        -- We expect the point count to go to zero, then we can adjust based on how many
        -- feats the character had selected (potentially driving the count to less than zero).
        tracker.Granted = currentFeatPointCount + E6_GetUsedFeatCount(entity)
        tracker.Pending = -currentFeatPointCount

        local charName = GetCharacterName(entity, true)
        _E6P("Point reset for " .. charName .. ": TargetFeatCount: 0, UsedFeatCount: 0, CurrentFeatPointCount: " .. tostring(currentFeatPointCount) .. ", DeltaFeatPointCount: " .. tostring(-currentFeatPointCount))
    end
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

    if not ent.Experience then
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
    local targetFeatCount = math.floor(xpToNextLevel/epic6FeatXP)

    local id = ent.Uuid.EntityUuid
    local usedFeatCount = E6_GetUsedFeatCount(ent)
    local currentFeatPointCount = E6_GetFeatPointBoostAmount(id)
    local totalGrantedFeatCount = currentFeatPointCount + usedFeatCount
    local deltaFeatCount = targetFeatCount - totalGrantedFeatCount

    -- If we have caught up from the total feat count expected to the amount granted, we are done.
    if deltaFeatCount == 0 then
        actionResourceTracker[id] = nil
        return
    end

    -- Track what we have last granted and wait until that is complete before granting more.
    local lastStats = GetCharacterTracker(id)

    -- We are still waiting for any pending feat points to be granted.
    -- Pending == 0 implies a new instance to track, and we have nothing to wait for.
    if lastStats.Pending ~= 0 and lastStats.Granted + lastStats.Pending ~= totalGrantedFeatCount then
        return
    end

    -- We are caught up, grant the delta pending
    lastStats.Granted = totalGrantedFeatCount
    lastStats.Pending = deltaFeatCount

    _E6P("Update for " .. charName .. ": TargetFeatCount: " .. tostring(targetFeatCount) .. ", UsedFeatCount: " .. tostring(usedFeatCount) .. ", CurrentFeatPointCount: " .. tostring(currentFeatPointCount) .. ", DeltaFeatPointCount: " .. tostring(deltaFeatCount))

    for i = 1, deltaFeatCount do
        Osi.ApplyStatus(id, "E6_FEAT_GRANTFEATPOINT", -1, -1, id)
    end
    for i = 1, -deltaFeatCount do
        Osi.ApplyStatus(id, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, id)
    end

    local hasSpell = Osi.HasSpell(id, EpicSpellContainerName)
    if totalGrantedFeatCount == 0 and targetFeatCount > 0 and not hasSpell then
        Osi.AddSpell(id, EpicSpellContainerName, 0, 0)
    elseif targetFeatCount == 0 and hasSpell then -- Remove the spell if we have no feats to grant.
        Osi.RemoveSpell(id, EpicSpellContainerName, 0)
    end
end

return FeatPointTracker
