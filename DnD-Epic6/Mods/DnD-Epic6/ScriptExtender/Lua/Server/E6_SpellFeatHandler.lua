
---We need to gather feats that have already been selected for the entity so we can filter if necessary.
---@param entity EntityHandle
---@return table
local function GatherPlayerFeats(entity)
    local feats = {}
    if entity == nil then
        return feats
    end
    local CCLevelUp = entity.CCLevelUp
    if CCLevelUp == nil then
        return feats
    end
    local function AddFeat(feat)
        if feat ~= nil and feat ~= "00000000-0000-0000-0000-000000000000" then
            --_E6P("Adding feat: " .. feat)
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

    local e6Feats = entity.Vars.E6_Feats
    if e6Feats ~= nil then
        for _, feat in ipairs(e6Feats) do
            AddFeat(feat.FeatId)
        end
    end
    return feats
end

---Determines if the character meets the requirements for a feat.
---@param feat table The feat to test for
---@param entity EntityHandle The entity to test against
---@return boolean True if the entity meets the requirements, false otherwise.
local function MeetsFeatRequirements(feat, entity, abilityScores)
    if not feat.HasRequirements then
        return true
    end
    for _, req in ipairs(feat.HasRequirements) do
        if not req(entity, abilityScores) then
            return false
        end
    end
    return true
end

---Gathers the feats that the player can select. It checks constraints server side as client doesn't
---seem to have all the data to do so.
---@param entity EntityHandle
---@param playerFeats table
---@param abilityScores table?
---@return table
local function GatherSelectableFeatsForPlayer(entity, playerFeats, abilityScores)
    local allFeats = E6_GatherFeats()

    local featList = {}
    for featId, feat in pairs(allFeats) do
        if feat.CanBeTakenMultipleTimes or playerFeats[featId] == nil then
            if MeetsFeatRequirements(feat, entity, abilityScores) then
                table.insert(featList, featId)
            end
        end
    end
    return featList
end

---Gathers the ability scores from the ability boosts.
---@param boosts EntityHandle There isn't a specific type for the boost container, so we'll just use the entity handle.
---@return table? The ability scores and their maximums, or nil if it could not be determined.
local function GatherAbilityScoresFromBoosts(boosts)
    if boosts == nil then
        return nil
    end

    local scores = {}
    for _,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        if boostInfo and boostInfo.Cause and (boostInfo.Cause.Type == "Character" or boostInfo.Cause.Type == "Progression" or boostInfo.Cause.Cause == "E6_Feat") then
            ---@type AbilityBoostComponent?
            local ability = boost.AbilityBoost
            if ability and ability.Ability and ability.Ability.Label then
                local abilityLabel = ability.Ability.Label
                if not scores[abilityLabel] then
                    scores[abilityLabel] = {Current = 0, Maximum = 20}
                end
                scores[abilityLabel].Current = scores[abilityLabel].Current + ability.Value
                scores[abilityLabel].Maximum = scores[abilityLabel].Maximum + ability.field_8 -- TODO: This field will likely get renamed in the future
            end
        end
    end
    return scores
end

---Gathers the ability scores for the given character, without magical modifications
---@param entity EntityHandle
---@return table?
local function GatherAbilityScores(entity)
    local boostContainer = entity.BoostsContainer
    if boostContainer == nil then
        return nil
    end
    local boosts = boostContainer.Boosts
    if boosts == nil then
        return nil
    end
    for _i,boost in ipairs(boosts) do
        if boost.Type and boost.Type.Label == "Ability" then
            return GatherAbilityScoresFromBoosts(boost.Boosts)
        end
    end
    return nil
end

---Handles when the Epic6 Feat spell is cast to bring up the UI on the client to select a feat.
---@param caster string
local function OnEpic6FeatSelectorSpell(caster)
    local ent = Ext.Entity.Get(caster)
    local charname = GetCharacterName(ent)
    _E6P(EpicSpellContainerName .. " was cast by " .. charname .. " (" .. caster .. ")")

    local playerFeats = GatherPlayerFeats(ent)
    local abilityScores = GatherAbilityScores(ent)
    local message = {
        PlayerId = caster,
        PlayerName = GetCharacterName(ent),
        PlayerFeats = playerFeats,
        SelectableFeats = GatherSelectableFeatsForPlayer(ent, playerFeats, abilityScores),
        Abilities = abilityScores -- we need their current scores and maximums to display UI
    }

    --_E6P("Stats.Abilities[0] = " .. tostring(ent.Stats.Abilities[0]))
    --_E6P("Stats.Abilities[1] = " .. tostring(ent.Stats.Abilities[1]))
    --_E6P("Stats.Abilities[2] = " .. tostring(ent.Stats.Abilities[2]))
    --_E6P("Stats.Abilities[3] = " .. tostring(ent.Stats.Abilities[3]))
    --_E6P("Stats.Abilities[4] = " .. tostring(ent.Stats.Abilities[4]))
    --_E6P("Stats.Abilities[5] = " .. tostring(ent.Stats.Abilities[5]))
    --_E6P("Stats.Abilities[6] = " .. tostring(ent.Stats.Abilities[6]))
    --_E6P("Stats.Abilities[7] = " .. tostring(ent.Stats.Abilities[7]))
    --_E6P("type(Stats.Abilities) = " .. tostring(type(ent.Stats.Abilities)))

    --local obj = E6_ToJson(ent, {"Party", "ServerReplicationDependencyOwner", "InventoryContainer"})
    --local str = Ext.Json.Stringify(obj)
    --Ext.IO.SaveFile("E6_character.json", str)
    --_E6P("Character saved!")

    --ent.BackgroundPassives?.field_18[].Passive uint32  -- TODO: This field will likely get renamed in the future
    --ent.OriginPassives?.field_18[].Passive uint32  -- TODO: This field will likely get renamed in the future
    --ent.PassiveContainer.Passives[] EntityHandle Uuid.Guid

    local str = Ext.Json.Stringify(message)
    _E6P(str)

    Ext.Net.PostMessageToClient(caster, NetChannels.E6_SERVER_TO_CLIENT_SHOW_FEAT_SELECTOR, str)
end

function E6_SpellFeatHandlerInit()
    _E6P("E6_Initializing spell feat handler.")
    Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function (caster, spell, _, _, _)
        if spell == EpicSpellContainerName then
            OnEpic6FeatSelectorSpell(caster)
        end
    end)
end