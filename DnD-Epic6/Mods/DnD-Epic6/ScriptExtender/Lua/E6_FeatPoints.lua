

local function E6_GetLevel6XP()
    local extraData = Ext.Stats.GetStatsManager().ExtraData
    return extraData.Level1 + extraData.Level2 + extraData.Level3 + extraData.Level4 + extraData.Level5
end

local function DE_GetEpicFeatXP()
    return Ext.Stats.GetStatsManager().ExtraData.Epic6FeatXP
end

--[[ Research
function DumpData(name, field)
    if not pcall(function()
        Ext.Utils.Print(name)
        _D(field)
    end) then
        Ext.Utils.Print("Failed to print " .. name)
    end
end

function FindEpic6Stat()
    _P("Experience to reach level 6: " .. E6_GetLevel6XP())
    _P("Experience for each Epic feat: " .. DE_GetEpicFeatXP())
end

function OnTurnEnded_GettingInfo(char)
    _P("Server Turn Ended: " .. char)
    local ent = Ext.Entity.Get(char)

    FindEpic6Stat()

    --DumpData("IsCharacter", ent.IsCharacter)
    DumpData("Experience", ent.Experience)
    DumpData("Classes", ent.Classes)
    -- How to dump ent.Vars?
    -- ent.Experience.CurrentLevelExperience has current level experience to divide by DE_GetEpicFeatXP() to determine feat count.
end

Ext.Osiris.RegisterListener("TurnEnded", 1, "after", OnTurnEnded_GettingInfo)
]]

local function E6_GetFeatPointBoostCommand(boostAmount)
    return "ActionResource(FeatPoint," .. tostring(boostAmount) .. ",0)"
end

local function E6_GetFeatPointBoostAmount(uuid)
    return  Osi.GetActionResourceValuePersonal(uuid, "FeatPoint", 0)
end

local function E6_AddFeatPointBoost(uuid, boostAmount)
    local cmd = E6_GetFeatPointBoostCommand(boostAmount)
    _P("DnD-Epic6: running command: " .. cmd)
    Osi.AddBoosts(uuid, cmd, "", uuid)
end

-- Cleans up the feat points and extra feat count from the given user after letting the 
-- character update/replicate after respec (doing this right in the callback behaves oddly).
local function E6_DeferredFeatCountCleanupFromRespec(entity)
    local id = entity.Uuid.EntityUuid
    Osi.RemoveSpell(id, EpicSpellContainerName, 0)
end

local function E6_DeferTickFor(entity, deferTickTracker, deferType, deferCallback, deferrenceCompleteCallback)
    local id = entity.Uuid.EntityUuid
    local deferCount = deferTickTracker[id]
    if deferCount ~= nil then
        deferCount = deferCount - 1
        if deferCount == 0 then
            deferTickTracker[id] = nil
            if deferrenceCompleteCallback ~= nil then
                deferrenceCompleteCallback(entity)
            end
        else
            deferTickTracker[id] = deferCount
            if deferCallback ~= nil then
                deferCallback(entity)
            end
        end
        --_P("DnD-Epic6: Deferring " .. deferType .. " tick update " .. tostring(deferCount) .. " more times for (level: " .. tostring(entity.EocLevel.Level) .. "): " .. id)
        return true
    end
    return false
end

local deferTickUpdateRespec = {}

-- After a respec, the entity still has some old data about the level count and will erroneously grant 
-- feat points when it shouldn't. Defer a given number of ticks for the character that was respecced 
-- so that the values can be updated.
local function E6_DeferTickRespec(entity)
    return E6_DeferTickFor(entity, deferTickUpdateRespec, "respec", nil, E6_DeferredFeatCountCleanupFromRespec)
end

local deferTickUpdateLevelUp = {}

-- Send AddBoost commands that don't do anything through the system to hopefully clear out the hitch with them registering.
local function E6_FlushBoostQueue(entity)
    local id = entity.Uuid.EntityUuid
    E6_AddFeatPointBoost(id, 0)
end

-- When a levelup completes, we need to defer a tick to let the character process before updating.
local function E6_DeferTickLevelUp(entity)
    return E6_DeferTickFor(entity, deferTickUpdateLevelUp, "levelup", nil, nil)
end

local actionResourceTracker = {}

-- Determines if the character can update their feat count, and if so, does so.
-- Only update if:
--  Their experience is at least level 6
--  They have selected all 6 class levels
--  They have enough experience to warrant feats.
local function E6_UpdateEpic6FeatCount(ent)
    if not ent.CharacterCreationStats then
        return
    end

    if not ent.CharacterCreationStats.Name then
        return
    end

    if E6_DeferTickRespec(ent) then
        return
    end

    if E6_DeferTickLevelUp(ent) then
        return
    end

    if not ent.Experience then
        return
    end

    local charName = ent.CharacterCreationStats.Name

    -- CurrentLevelExperience is the experience from 6 to 7 we have accumulated. 
    -- The XP Data is constructed in such a way that the XP cap is reached before level 7
    -- xp can be earned, so you never really reach level 7.
    local totalFeatCount = 0

    -- If we have enough experience and our level is high enough, compute what our total feat count ought to be.
    if ent.Experience.TotalExperience > E6_GetLevel6XP() and ent.EocLevel.Level >= 6 then
        local xpToNextLevel = ent.Experience.CurrentLevelExperience
        local epic6FeatXP = DE_GetEpicFeatXP()
        totalFeatCount = math.floor(xpToNextLevel/epic6FeatXP)
    end

    local id = ent.Uuid.EntityUuid
    local usedFeatCount = Osi.GetActionResourceValuePersonal(id, "UsedFeatPoints", 0) or 0
    local currentFeatCount = E6_GetFeatPointBoostAmount(id)

    -- Track the changes in the resources. If we spot a resource change, add a delay of 10 ticks before
    -- recomputing the delta to apply.
    if actionResourceTracker[id] == nil then
        actionResourceTracker[id] = {}
    end
    local lastStats = actionResourceTracker[id]
    if lastStats.Current ~= currentFeatCount or lastStats.Used ~= usedFeatCount then
        lastStats.Current = currentFeatCount
        lastStats.Used = usedFeatCount
        deferTickUpdateLevelUp[id] = 10
        return
    end

    local deltaFeatCount = totalFeatCount - currentFeatCount - usedFeatCount

    if deltaFeatCount ~= 0 then
        _P("DnD-Epic6: " .. charName .. ": TotalFeatCount: " .. tostring(totalFeatCount) .. ", UsedFeatCount: " .. tostring(usedFeatCount) .. ", CurrentFeatCount: " .. tostring(currentFeatCount) .. ", DeltaFeatCount: " .. tostring(deltaFeatCount))
        E6_AddFeatPointBoost(id, deltaFeatCount)
        deferTickUpdateLevelUp[id] = 10
    end

    if currentFeatCount + usedFeatCount == 0 and totalFeatCount > 0 then
        Osi.AddSpell(id, EpicSpellContainerName, 0, 0)
    end
end

-- Given an array of character guids, get their corresponding entity and 
-- update the feat count.
local function E6_UpdateEpic6FeatCountForAllById(chars)
    for _,char in pairs(chars) do
        if char ~= nil then
            local ent = Ext.Entity.Get(char)
            if ent == nil then
                _P("DnD-Epic6: Character entity not found for uuid: " .. char)
                return
            end
            E6_UpdateEpic6FeatCount(char)
        end
    end
end

-- Given an array of character entities, update their feat count
local function E6_UpdateEpic6FeatCountForAllByEntity(chars)
    for _,char in pairs(chars) do
        if char ~= nil then
            E6_UpdateEpic6FeatCount(char)
        end
    end
end

-- Determines if we can safely update the feat counts for the party.
local function E6_CanUpdateEpic6FeatCounts()
    -- No character, no party to retrieve to update.
    if Osi.GetHostCharacter == nil then
        return nil
    end
    -- _D(_C().Uuid.EntityUuid)
    -- Ensure we can safely get the character, too (some game states outside of running it doesn't work for)
    local success, char = pcall(function()
        return Osi.GetHostCharacter()
    end)

    if not success or char == nil then
        --_P("DnD-Epic6: Skipping update--call result: " .. tostring(success) .. ", character: " .. tostring(char))
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

    -- I was considering updating everyone, but that seems more expensive and
    -- unnecessary, but I'll keep this as a reference just in case game behaviour
    -- changes and it becomes useful again.
    --[[ 
    local otherChars = {
        "S_Player_Karlach_2c76687d-93a2-477b-8b18-8a14b549304c"
        , "S_Player_Minsc_0de603c5-42e2-4811-9dad-f652de080eba"
        , "S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b" -- Minthara
        , "S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323"
        , "S_Player_Jaheira_91b6b200-7d00-4d62-8dc9-99e8339dfa1a"
        , "S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604"
        , "S_Player_Astarion_c7c13742-bacd-460a-8f65-f864fe41f255"
        , "S_Player_Laezel_58a69333-40bf-8358-1d17-fff240d7fb12"
        , "S_Player_Wyll_c774d764-4a17-48dc-b470-32ace9ce447d"
        , "S_Player_ShadowHeart_3ed74f06-3c60-42dc-83f6-f034cb47c679"
    }
    E6_UpdateEpic6FeatCountForAllById(otherChars)
    ]]
end

local function E6_OnGameStateChanged(e)
    if e.FromState == Ext.Enums.ServerGameState.Running then
        E6_CanUpdate = false
    elseif e.ToState == Ext.Enums.ServerGameState.Running then
        E6_CanUpdate = true
    end
    _P("DnD-Epic6: Server State change from " .. e.FromState.Label .. " to " .. e.ToState.Label)
end

local function E6_OnLevelUpComplete(characterGuid)
    _P("DnD-Epic6: Level up completed with id: " .. characterGuid)
    -- When a levelup completes, we need to defer a tick to let the character process before updating.
    local id = GetHostCharacter()
    deferTickUpdateLevelUp[id] = 10
end

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

local function E6_OnRespecComplete(characterGuid)
    -- When a respec completes, we'll reset the number of feat points & the feat granter spell.
    -- Then the Tick will handle updating the feat count so the player can select them again.
    local id = GetHostCharacter()
    local char = _C()
    -- When entering levels, the various creatures in the level trigger the respec, resulting in 
    -- deferTickUpdateRespec adding a lot of entries to the table without getting them removed.
    -- Narrow the ones processed to those that have the IsPlayer flag.
    if not E6_IsPlayerEntity(char) then
        return
    end
    _P("DnD-Epic6: Respec completed with id: " .. characterGuid)
    deferTickUpdateRespec[id] = 10
end


function E6_FeatPointInit()
    -- Tracks changes in the game state so we are only updating feats when
    -- we are in the Running state.
    Ext.Events.GameStateChanged:Subscribe(E6_OnGameStateChanged)

    -- Checking every tick seems less than optimal, but not sure where to hook just for
    -- experience granted to perform the test to update the feat count.
    Ext.Events.Tick:Subscribe(E6_OnTick_UpdateEpic6FeatCount)

    Ext.Osiris.RegisterListener("LeveledUp", 1, "after", E6_OnLevelUpComplete)
    Ext.Osiris.RegisterListener("RespecCompleted", 1, "after", E6_OnRespecComplete)
end