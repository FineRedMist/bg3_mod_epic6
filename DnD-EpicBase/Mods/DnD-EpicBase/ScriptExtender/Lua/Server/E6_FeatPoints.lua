
local pastLifeRegressionsFeatId = "fe70bd84-7406-42c7-8c50-115022a37e82"

--- @enum QueuedBackgroundGoalStatus
local QueuedBackgroundGoalStatus = {
	Added = 0,
	Committing = 1,
	[0] = "Added",
	[1] = "Committing",
}

---@class QueuedBackgroundGoal
---@field Character GUIDSTRING The ID of the character.
---@field Goal GUIDSTRING The ID of the background goal.
---@field GoalBackgroundId GUIDSTRING The ID of the background to switch to.
---@field CurrentBackgroundId GUIDSTRING The ID of the player's current background.
---@field Category string The category for the goal
---@field Status QueuedBackgroundGoalStatus The status of the queued goal.

---@type QueuedBackgroundGoal[]
local queuedBackgroundGoals = {}

---Takes the first pending goal in the queued goals to apply if it isn't already in progress.
local function ApplyQueuedBackgroundGoals()
    for _, goal in ipairs(queuedBackgroundGoals) do
        if goal.Status ~= QueuedBackgroundGoalStatus.Added then
            return
        end
        -- _E6P("Applying queued background goal for character " .. tostring(goal.Character) .. " goal " .. tostring(goal.Goal))
        goal.Status = QueuedBackgroundGoalStatus.Committing

        local player = Ext.Entity.Get(goal.Character)
        player.Background.Background = goal.GoalBackgroundId
        Osi.AddBackgroundGoal(goal.Character, goal.Goal, goal.Category)
        return
    end
end

---Finishes the application of any queued background goals by restoring the player's background id.
---@param status string Whether the goal was "Completed" or "Failed".
---@return boolean True if a queued goal was finished, false otherwise.
local function FinishBackgroundGoalApplication(status)
    local removeIndex = -1
    for index, goal in ipairs(queuedBackgroundGoals) do
        if goal.Status == QueuedBackgroundGoalStatus.Committing then
            --_E6P(status .. " queued background goal for character " .. tostring(goal.Character) .. " goal " .. tostring(goal.Goal))

            removeIndex = index

            local player = Ext.Entity.Get(goal.Character)
            player.Background.Background = goal.CurrentBackgroundId
        end
    end

    if removeIndex > 0 then
        table.remove(queuedBackgroundGoals, removeIndex)
        return true
    end
    return false
end


---Closes the UI for the given character.
---@param char string The character ID
function E6_NetCloseUI(char)
    local result = Ext.Net.PostMessageToClient(char, NetChannels.E6_SERVER_TO_CLIENT_CLOSE_UI, char)
    _E6P("E6_NetCloseUI result: " .. tostring(result))
end

---Ensure that the character's level limit is constrained to the maximum level.
---@param entity EntityHandle
local function FixupLevelLimit(entity)
    if entity.AvailableLevel and entity.AvailableLevel.Level > E6_GetMaxLevel() then
        _E6P("Setting available level for " .. GetCharacterName(entity) .. " from " .. tostring(entity.AvailableLevel.Level) .. " to " .. tostring(E6_GetMaxLevel()))
        entity.AvailableLevel.Level = E6_GetMaxLevel()
    end
    --if entity.ServerCharacter and entity.ServerCharacter.Template and entity.ServerCharacter.Template.LevelOverride > E6_GetMaxLevel() then
    --    entity.ServerCharacter.Template.LevelOverride = E6_GetMaxLevel()
    --end
end

---We need to gather feats that have already been selected for the entity so we can filter if necessary.
---@param entity EntityHandle The player entity to gather feats for.
---@return table<string, number> The count of occurrences for each feat. 
function E6_GatherPlayerFeats(entity)
    local feats = {}
    if entity == nil then
        return feats
    end
    local CCLevelUp = entity.CCLevelUp
    if CCLevelUp == nil then
        return feats
    end
    local function AddFeat(feat)
        if IsValidGuid(feat) then
            local curCount = feats[feat]
            if curCount == nil then
                curCount = 1
            else
                curCount = curCount + 1
            end
            feats[feat] = curCount
        end
    end

    for _, levelup in ipairs(CCLevelUp.LevelUps) do
        AddFeat(levelup.Feat)
        if levelup.Upgrades ~= nil then
            for _, upgrade in ipairs(levelup.Upgrades.Feats) do
                AddFeat(upgrade.Feat)
            end
        end
    end

    ---@type SelectedFeatType[]
    local e6Feats = entity.Vars.E6_Feats
    if e6Feats ~= nil then
        for _, feat in ipairs(e6Feats) do
            AddFeat(feat.FeatId)
        end
    end
    return feats
end

-- Given an array of character entities, update their feat count
---@param chars EntityHandle[] The list of character entities to update with the feat granting spell.
local function E6_UpdateEpic6FeatCountForAllByEntity(chars)
    for _,char in pairs(chars) do
        if EntityHasID(char) then
            local inCombat = IsEntityInCombat(char)
            local inDialog = char.DialogState and char.DialogState.field_0 ~= 0
            if char.Vars.E6_InCombat ~= inCombat then
                char.Vars.E6_InCombat = inCombat
            end
            if char.Vars.E6_InDialog ~= inDialog then
                char.Vars.E6_InDialog = inDialog
            end

            FixupLevelLimit(char)
            FeatPointTracker:Update(char)
        end
    end
end

-- Tracks whether it is safe to be trying to update the feat count or not.
-- We only do this in the Running state of the game.
local E6_CanUpdate = false

function E6_OnTick_UpdateEpic6FeatCount(tickParams)
    ApplyQueuedBackgroundGoals()

    -- Only update when we are in the Running state.
    if not E6_CanUpdate then
        return
    end

    local clientEntities = GetClientEntities()
    for _,client in ipairs(clientEntities) do
        -- Update the feat count for all party members -- we don't bother with other non-party members 
        -- since you can't currently level them up without them being in your party.
        if client.PartyMember and client.PartyMember.Party and client.PartyMember.Party.PartyView then
            E6_UpdateEpic6FeatCountForAllByEntity(client.PartyMember.Party.PartyView.Characters)
        end
    end
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
    -- Tick will handle updating the feat count so the player can select them again once the respect is complete 
    -- (and they level back up).
    FeatPointTracker:OnRespecComplete(char)
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

    FeatPointTracker:OnRespecCancel(char)
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

    E6_NetCloseUI(GetEntityID(char))
    FeatPointTracker:OnRespecBegin(char)
end

--- Example: E6[Server]: BackgroundGoalFailed called for character Elves_Female_Everic_Player_b094fac2-9324-544d-76b2-e2a300399034 goal 92f75626-3bdd-4bb8-b5a5-2750c5e61c0d
---@param character CHARACTER The character the goal was being applied to.
---@param goal GUIDSTRING The id of the goal being rewarded.
local function BackgroundGoalFailed(character, goal)
    --_E6P("BackgroundGoalFailed called for character " .. tostring(character) .. " goal " .. tostring(goal))

    -- Check queued background goals to make sure we don't double queue
    if FinishBackgroundGoalApplication("Failed") then
        return
    end

    local player = Ext.Entity.Get(character)

    if not player then
        _E6Error("BackgroundGoalFailed: Could not find entity for character " .. tostring(character))
        return
    end

    if not player.Background or not player.Background.Background then
        _E6Error("BackgroundGoalFailed: Could not find background component for character " .. tostring(character))
        return
    end

    -- Get the corresponding background goal
    ---@type ResourceBackgroundGoal
    local goalResource = Ext.StaticData.Get(goal, Ext.Enums.ExtResourceManagerType.BackgroundGoal)
    if not goalResource then
        _E6Error("BackgroundGoalFailed: Could not find background goal for GUID " .. tostring(goal))
        return
    end

    local feats = E6_GatherPlayerFeats(player)
    if feats[pastLifeRegressionsFeatId] == nil then
        return
    end

    -- Queue applying the background goal
    ---@type QueuedBackgroundGoal
    local queuedGoal = {
        Character = character,
        Goal = goal,
        GoalBackgroundId = goalResource.BackgroundUuid,
        CurrentBackgroundId = player.Background.Background,
        Category = "Act1",
        Status = QueuedBackgroundGoalStatus.Added
    }
    table.insert(queuedBackgroundGoals, queuedGoal)
end

--- Example: E6[Server]: BackgroundGoalFailed called for character Elves_Female_Everic_Player_b094fac2-9324-544d-76b2-e2a300399034 goal 92f75626-3bdd-4bb8-b5a5-2750c5e61c0d
---@param character CHARACTER The character the goal was being applied to.
---@param goal GUIDSTRING The id of the goal being rewarded.
local function BackgroundGoalRewarded(character, goal)
    --_E6P("BackgroundGoalRewarded called for character " .. tostring(character) .. " goal " .. tostring(goal))
    FinishBackgroundGoalApplication("Completed")
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
    Ext.Osiris.RegisterListener("BackgroundGoalFailed", 2, "after", BackgroundGoalFailed)
    Ext.Osiris.RegisterListener("BackgroundGoalRewarded", 2, "after", BackgroundGoalRewarded)
end