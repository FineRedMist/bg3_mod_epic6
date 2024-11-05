

---Closes the UI for the given character.
---@param char string The character ID
function E6_NetCloseUI(char)
    Ext.Net.PostMessageToClient(char, NetChannels.E6_SERVER_TO_CLIENT_CLOSE_UI, char)
end

-- Given an array of character entities, update their feat count
---@param chars EntityHandle[] The list of character entities to update with the feat granting spell.
local function E6_UpdateEpic6FeatCountForAllByEntity(chars)
    for _,char in pairs(chars) do
        if EntityHasID(char) and not IsEntityInCombat(char) then
            FeatPointTracker:Update(char)
        end
    end
end

-- Tracks whether it is safe to be trying to update the feat count or not.
-- We only do this in the Running state of the game.
local E6_CanUpdate = false

function E6_OnTick_UpdateEpic6FeatCount(tickParams)
    -- Only update when we are in the Running state.
    if not E6_CanUpdate then
        return
    end

    if not Osi or not Osi.IsInCombat then
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

    E6_NetCloseUI(characterGuid)
    FeatPointTracker:OnRespecBegin(char.Uuid.EntityUuid)
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
end