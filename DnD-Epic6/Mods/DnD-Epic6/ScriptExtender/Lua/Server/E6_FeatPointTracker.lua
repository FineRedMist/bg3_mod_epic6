--- @class FeatPointTracker A double-ended queue.
---Maps the entity id to an object that tracks the last known feat count and the granted feat count.
FeatPointTracker = {}
FeatPointTracker.__index = FeatPointTracker

---@type table<GUIDSTRING, boolean> The mapping of character ID to character point tracker.
local IsRespecing = {}
---@type table<GUIDSTRING, integer> The mapping of character ID to how many feat points the character is expected to have been granted.
local PendingFeatPoints = {}
---@type table<GUIDSTRING, integer> The mapping of character ID to tick wait to test pending points are granted.
local PendingTickWait = {}

local UseBoosts = false
local FeatPointBoostName = "ActionResource(FeatPoint,1,0)"
---Adds a feat point for the character
---@param id GUIDSTRING
local function AddFeatPoint(id)
    if UseBoosts then
        Osi.AddBoosts(id, FeatPointBoostName, "E6_Feats", id)
    else
        Osi.ApplyStatus(id, "E6_FEAT_GRANTFEATPOINT", -1, -1, id)
    end
end

---Removes a feat point for the character
---@param id GUIDSTRING
local function RemoveFeatPoint(id)
    if UseBoosts then
        Osi.RemoveBoost(id, FeatPointBoostName, 1, "E6_Feats", id)
    else
        Osi.ApplyStatus(id, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, id)
    end
end

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
    if UseBoosts then
        Osi.RemoveBoost(id, FeatPointBoostName, 0, "E6_Feats", id)
    else
        Osi.RemoveStatus(id, "E6_FEAT_GRANTFEATPOINT", id)
        Osi.RemoveStatus(id, "E6_FEAT_CONSUMEFEATPOINT", id)
    end
end


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
    IsRespecing[characterGuid] = true
    local charName = GetCharacterName(entity, true)
    if entity.Vars.E6_Feats then
        E6_RemoveFeats(characterGuid, entity.Vars.E6_Feats)
    end
    _E6P("Respec for " .. charName .. " started.")
end

function FeatPointTracker:OnRespecCancel(entity)
    local characterGuid = entity.Uuid.EntityUuid
    IsRespecing[characterGuid] = false
    local charName = GetCharacterName(entity, true)
    _E6P("Respec for " .. charName .. " cancelled.")

    if entity.Vars.E6_Feats then
        E6_ApplyFeats(characterGuid, entity.Vars.E6_Feats)
    end
end

function FeatPointTracker:OnRespecComplete(entity)
    local characterGuid = entity.Uuid.EntityUuid
    local wasRespecStarted = IsRespecing[characterGuid]
    IsRespecing[characterGuid] = false
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
    end
end

local function HasFeatGrantingSpell(id)
    local hasSpell = Osi.HasSpell(id, EpicSpellContainerName)
    if not hasSpell or hasSpell == 0 then
        return false
    end
    return true
end

---comment
---@param id GUIDSTRING
---@param val number?
local function SetPendingFeatCount(id, val)
    PendingFeatPoints[id] = val
    PendingTickWait[id] = 5
end


local function UpdateFeatGrantingSpell(id, charName, targetFeatCount)
    local hasSpell = HasFeatGrantingSpell(id)
    --_E6P("Character " .. charName .. " has feat granting spell: " .. tostring(hasSpell) .. ", target feat count: " .. tostring(targetFeatCount))
    if targetFeatCount >= 1 and not hasSpell then
        _E6P("Character " .. charName .. " is adding spell " .. EpicSpellContainerName)
        Osi.AddSpell(id, EpicSpellContainerName, 0, 0)
        SetPendingFeatCount(id)
    elseif targetFeatCount < 1 and hasSpell then -- Remove the spell if we have no feats to grant.
        _E6P("Character " .. charName .. " is removing spell " .. EpicSpellContainerName)
        Osi.RemoveSpell(id, EpicSpellContainerName, 0)
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
    if ShouldWaitForLaterTick(id) then
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

    local usedFeatCount = E6_GetUsedFeatCount(ent)
    local currentFeatPointCount = E6_GetFeatPointBoostAmount(id)
    local totalGrantedFeatCount = currentFeatPointCount + usedFeatCount
    local deltaFeatCount = targetFeatCount - totalGrantedFeatCount

    UpdateFeatGrantingSpell(id, charName, targetFeatCount)

    -- If we have caught up from the total feat count expected to the amount granted, we are done.
    if deltaFeatCount == 0 then
        PendingFeatPoints[id] = nil
    elseif targetFeatCount == 0 then
        -- If we have no feats to grant, we should remove all the feat points.
        _E6P("Update for " .. charName .. ": removing all points")
        RemoveAllFeatPoints(id)
        SetPendingFeatCount(id)
    else
        local pending = PendingFeatPoints[id]
        if pending == nil then
            pending = 0
        end
        -- Only grant half the remaining feats per tick.
        local difference = deltaFeatCount - pending
        local toAdjust = math.ceil(difference / 2)
        if -0.75 < toAdjust and toAdjust < 0.75 then
            toAdjust = difference
        end

        _E6P("Update for " .. charName .. ": TargetFeatCount: " .. tostring(targetFeatCount) .. ", UsedFeatCount: " .. tostring(usedFeatCount) .. ", CurrentFeatPointCount: " .. tostring(currentFeatPointCount) .. ", DeltaFeatPointCount: " .. tostring(deltaFeatCount) .. ", adjusting by: " .. tostring(toAdjust))

        AdjustFeatPoints(id, toAdjust)
        SetPendingFeatCount(id, toAdjust)
    end
end

return FeatPointTracker
