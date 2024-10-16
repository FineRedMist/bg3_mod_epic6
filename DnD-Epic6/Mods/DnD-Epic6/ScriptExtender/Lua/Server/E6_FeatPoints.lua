

---@return number
local function E6_GetLevel6XP()
    local extraData = Ext.Stats.GetStatsManager().ExtraData
    return extraData.Level1 + extraData.Level2 + extraData.Level3 + extraData.Level4 + extraData.Level5
end

---Retrieves the amount of experience required for the character to earn a feat.
---@param char EntityHandle The character entity to retrieve the value or the default.
---@return number
function DE_GetEpicFeatXP(char)
    local setting = char.Vars.E6_XPPerFeat
    if type(setting) == "number" and setting >= 100 and setting <= 20000 then
        return setting
    end
    return Ext.Stats.GetStatsManager().ExtraData.Epic6FeatXP
end

---@param uuid string
---@return (string|number)?
local function E6_GetFeatPointBoostAmount(uuid)
    return  Osi.GetActionResourceValuePersonal(uuid, "FeatPoint", 0)
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

-- Maps the entity id to an object that tracks the last known feat count and the granted feat count.
local actionResourceTracker = {}

---Resets the feat points on all entities that have the Experience component.
function ResetFeatPointsOnAll()
    for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("Experience")) do
        if entity.Uuid then
            local characterGuid = entity.Uuid.EntityUuid
            Osi.RemoveStatus(characterGuid, "E6_FEAT_GRANTFEATPOINT", characterGuid)
            Osi.RemoveStatus(characterGuid, "E6_FEAT_CONSUMEFEATPOINT", characterGuid)
        end
    end
    -- Clear the tracker as all values on it are now invalid.
    actionResourceTracker = {}
end

-- Determines if the character can update their feat count, and if so, does so.
-- Only update if:
--  Their experience is at least level 6
--  They have selected all 6 class levels
--  They have enough experience to warrant feats.
---@param ent EntityHandle
local function E6_UpdateEpic6FeatCount(ent)
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
    local totalFeatCount = 0

    -- If we have enough experience and our level is high enough, compute what our total feat count ought to be.
    if ent.Experience.TotalExperience < E6_GetLevel6XP() or ent.EocLevel.Level < 6 then
        return
    end

    local xpToNextLevel = ent.Experience.CurrentLevelExperience
    local epic6FeatXP = DE_GetEpicFeatXP(ent)
    totalFeatCount = math.floor(xpToNextLevel/epic6FeatXP)

    local id = ent.Uuid.EntityUuid
    local usedFeatCount = E6_GetUsedFeatCount(ent)
    local currentFeatCount = E6_GetFeatPointBoostAmount(id)
    local totalGrantedFeatCount = currentFeatCount + usedFeatCount
    local deltaFeatCount = totalFeatCount - totalGrantedFeatCount

    -- If we have caught up from the total feat count expected to the amount granted, we are done.
    if deltaFeatCount == 0 then
        actionResourceTracker[id] = nil
        return
    end

    -- Track what we have last granted and wait until that is complete before granting more.
    if actionResourceTracker[id] == nil then
        actionResourceTracker[id] = {}
    end
    local lastStats = actionResourceTracker[id]

    -- We are still waiting for any pending feat points to be granted.
    if lastStats.Granted == totalGrantedFeatCount then
        return
    end
    
    -- We are caught up, grant the delta pending
    lastStats.Granted = totalGrantedFeatCount
    lastStats.Pending = deltaFeatCount

    _E6P(charName .. ": TotalFeatCount: " .. tostring(totalFeatCount) .. ", UsedFeatCount: " .. tostring(usedFeatCount) .. ", CurrentFeatCount: " .. tostring(currentFeatCount) .. ", DeltaFeatCount: " .. tostring(deltaFeatCount))
    for i = 1, deltaFeatCount do
        Osi.ApplyStatus(id, "E6_FEAT_GRANTFEATPOINT", -1, -1, id)
    end
    for i = 1, -deltaFeatCount do
        Osi.ApplyStatus(id, "E6_FEAT_CONSUMEFEATPOINT", -1, -1, id)
    end

    if totalGrantedFeatCount == 0 and totalFeatCount > 0 then
        Osi.AddSpell(id, EpicSpellContainerName, 0, 0)
    end
end

-- Given an array of character entities, update their feat count
---@param chars EntityHandle[]
local function E6_UpdateEpic6FeatCountForAllByEntity(chars)
    for _,char in pairs(chars) do
        if char ~= nil then
            E6_UpdateEpic6FeatCount(char)
        end
    end
end

-- Determines if we can safely update the feat counts for the party.
-- Returns the main charater entity if we can.
---@return EntityHandle?
local function E6_CanUpdateEpic6FeatCounts()
    -- No character, no party to retrieve to update.
    if not Osi or not Osi.GetHostCharacter then
        return nil
    end

    -- Ensure we can safely get the character, too (some game states outside of running it doesn't work for)
    local success, char = pcall(function()
        return Osi.GetHostCharacter()
    end)

    if not success or char == nil then
        return nil
    end

    -- Ensure we can get the entity for the character.
    local ent = Ext.Entity.Get(char)
    if char == nil then
        return nil
    end

    -- Do we have a party member... member on the character?
    if ent.PartyMember == nil then
        return nil
    end

    -- Ensure we have a party that we can gather the party members for.
    if ent.PartyMember.Party == nil then
        return nil
    end
    return ent
end

-- Tracks whether it is safe to be trying to update the feat count or not.
-- We only do this in the Running state of the game.
local bool E6_CanUpdate = false

local function E6_OnTick_UpdateEpic6FeatCount(tickParams)
    -- Only update when we are in the Running state.
    if not E6_CanUpdate then
        return
    end

    -- Only update if we can get the data we need.
    local ent = E6_CanUpdateEpic6FeatCounts()
    if ent == nil then
        return
    end

    -- Update the feat count for all party members -- we don't bother with other
    -- non-party members since you can't currently level them up without them being
    -- in your party.
    E6_UpdateEpic6FeatCountForAllByEntity(ent.PartyMember.Party.PartyView.Characters)
end

---@param e EclLuaGameStateChangedEvent
local function E6_OnGameStateChanged(e)
    if e.FromState == Ext.Enums.ServerGameState.Running then
        E6_CanUpdate = false
    elseif e.ToState == Ext.Enums.ServerGameState.Running then
        E6_CanUpdate = true
    end
end

---@param ent EntityHandle
---@return boolean
local function E6_IsPlayerEntity(ent)
    if ent == nil then
        return false
    end
    if ent.ServerCharacter == nil then
        return false
    end
    if ent.ServerCharacter.Flags == nil then
        return false
    end
    for _,v in ipairs(ent.ServerCharacter.Flags) do
        if v == "IsPlayer" then
            return true
        end
    end
    return false
end

---@param characterGuid string
local function E6_OnRespecComplete(characterGuid)
    -- When entering levels, the various creatures in the level trigger the respec, ignore them
    -- by only focusing on those that have the IsPlayer flag.
    local char = Ext.Entity.Get(characterGuid)
    if not E6_IsPlayerEntity(char) then
        return
    end
    
    -- When a respec completes, we'll remove the feat granter spell, the feat counts, and feat that were previously granted.
    -- We needed to preserve the feat list from starting the respec in case it was cancelled so we could restore it.

    -- Tick will handle updating the feat count so the player can select them again once the respect is complete.
    Osi.RemoveSpell(characterGuid, EpicSpellContainerName, 0)
    Osi.RemoveStatus(characterGuid, "E6_FEAT_GRANTFEATPOINT", characterGuid)
    Osi.RemoveStatus(characterGuid, "E6_FEAT_CONSUMEFEATPOINT", characterGuid)
    actionResourceTracker[characterGuid] = nil -- clear any data for points in flight.
    if char.Vars.E6_Feats then
        char.Vars.E6_Feats = nil
    end
end

---If the user cancels the respec, we reapply the feats that were removed when the respec was started.
---@param characterGuid string
local function E6_OnRespecCancelled(characterGuid)
    -- When entering levels, the various creatures in the level trigger the respec, ignore them
    -- by only focusing on those that have the IsPlayer flag.
    local char = Ext.Entity.Get(characterGuid)
    if not E6_IsPlayerEntity(char) then
        return
    end
    if char.Vars.E6_Feats then
        E6_ApplyFeats(characterGuid, char.Vars.E6_Feats)
    end
end

---We need to remove the feat passives and boosts ahead of time as it may create erroneous behaviour during the respec itself.
---If the user cancels the respec, we reapply the feats.
---@param characterGuid string
local function E6_OnRespecStart(characterGuid)
    -- When entering levels, the various creatures in the level trigger the respec, ignore them
    -- by only focusing on those that have the IsPlayer flag.
    local char = Ext.Entity.Get(characterGuid)
    if not E6_IsPlayerEntity(char) then
        return
    end
    if char.Vars.E6_Feats then
        E6_RemoveFeats(characterGuid, char.Vars.E6_Feats)
    end
end

---We need to remove the feat passives and boosts ahead of time as it may create erroneous behaviour during the respec itself.
---If the user cancels the respec, we reapply the feats.
---@param characterGuid string
local function E6_OnRespecRequest(characterGuid)
    -- When entering levels, the various creatures in the level trigger the respec, ignore them
    -- by only focusing on those that have the IsPlayer flag.
    local char = Ext.Entity.Get(characterGuid)
    if not E6_IsPlayerEntity(char) then
        return
    end
    if char.Vars.E6_Feats then
        E6_RemoveFeats(characterGuid, char.Vars.E6_Feats)
    end
end

function E6_FeatPointInit()
    -- Tracks changes in the game state so we are only updating feats when
    -- we are in the Running state.
    Ext.Events.GameStateChanged:Subscribe(E6_OnGameStateChanged)

    -- Checking every tick seems less than optimal, but not sure where to hook just for
    -- experience granted to perform the test to update the feat count.
    Ext.Events.Tick:Subscribe(E6_OnTick_UpdateEpic6FeatCount)

    --Ext.Osiris.RegisterListener("LeveledUp", 1, "after", E6_OnLevelUpComplete)
    Ext.Osiris.RegisterListener("RespecCompleted", 1, "after", E6_OnRespecComplete)
    Ext.Osiris.RegisterListener("RespecCancelled", 1, "after", E6_OnRespecCancelled)
    Ext.Osiris.RegisterListener("StartRespec", 1, "before", E6_OnRespecStart)
    Ext.Osiris.RegisterListener("RequestRespec", 1, "before", E6_OnRespecRequest)
end