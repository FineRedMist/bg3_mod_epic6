
---We need to gather feats that have already been selected for the entity so we can filter if necessary.
---@param entity EntityHandle The player entity to gather feats for.
---@return table<string, number> The count of occurrences for each feat. 
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

---We need to gather passives that have already been selected for the entity so we can filter if necessary.
---@param entity EntityHandle The player entity to gather passives for.
---@return table<string, number> The count of occurrences for each passive. 
local function GatherPlayerPassives(entity)
    local passives = {}
    if entity == nil then
        return passives
    end
    local passiveContainer = entity.PassiveContainer
    if passiveContainer == nil then
        return passives
    end
    local playerPassives = passiveContainer.Passives
    if playerPassives == nil then
        return passives
    end
    local function AddPassive(passive)
        if passive == nil or string.len(passive) == 0 then
            return
        end
        _E6P("Adding passive: " .. passive)
        local curCount = passives[passive]
        if curCount == nil then
            curCount = 1
        else
            curCount = curCount + 1
        end
        passives[passive] = curCount
    end

    for _, playerPassiveObject in ipairs(playerPassives) do
        local playerPassive = playerPassiveObject.Passive
        if playerPassive and (not playerPassive.field_8 or playerPassive.field_8.ProgressionMeta) then
            AddPassive(playerPassive.PassiveId)
        end
    end

    local e6Feats = entity.Vars.E6_Feats
    if e6Feats ~= nil then
        for _, feat in ipairs(e6Feats) do
            if feat.PassivesAdded then
                for _,passive in ipairs(feat.PassivesAdded) do
                    AddPassive(passive)
                end
            end
        end
    end
    return passives
end

---Determines if the character meets the requirements for a feat.
---@param feat table The feat to test for
---@param entity EntityHandle The entity to test against
---@return boolean True if the entity meets the requirements, false otherwise.
local function MeetsFeatRequirements(feat, entity, playerInfo)
    if not feat.HasRequirements then
        return true
    end
    for _, req in ipairs(feat.HasRequirements) do
        if not req(entity, playerInfo) then
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
local function GatherSelectableFeatsForPlayer(entity, playerFeats, playerInfo)
    local allFeats = E6_GatherFeats()

    local featList = {}
    for featId, feat in pairs(allFeats) do
        if feat.CanBeTakenMultipleTimes or playerFeats[featId] == nil then
            if MeetsFeatRequirements(feat, entity, playerInfo) then
                table.insert(featList, featId)
            end
        end
    end
    return featList
end

---Determines if the boost should be included for the character.
---@param entity EntityHandle The character entity
---@param boost EntityHandle The boost instance
---@param boostInfo BoostInfoComponent? The boost info component
---@return boolean True if the boost should be included, false otherwise.
local function IsValidCause(entity, boost, boostInfo)
    if not boostInfo then
        return false
    end
    if not boostInfo.Cause then
        return false
    end
    local causeInfo = boostInfo.Cause
    local cause = causeInfo.Type.Label
    if cause == "Character" or cause == "Progression" or causeInfo.Cause == "E6_Feat" then
        return true
    end
    if cause ~= "Passive" then
        return false
    end
    -- We have a passive (such as actor) for which we have to check the passive as well, as some items use passives to grant ability boosts.
    if not causeInfo.Entity then
        return false
    end
    -- The passive data indicates this passive was granted by a progression, so we can include it.
    local progressionMeta = nil
    pcall(function() progressionMeta = causeInfo.Entity.ProgressionMeta end)
    if progressionMeta then
        return true
    end
    -- Ensure the passive id matches the cause id
    local passive = nil
    pcall(function() passive = causeInfo.Entity.Passive end)
    if not passive then
        return false
    end
    local passiveId = nil
    pcall(function() passiveId = passive.PassiveId end)
    if not passiveId then
        return false
    end
    if passiveId ~= causeInfo.Cause then
        return false
    end

    ---@type BackgroundComponent
    local backgroundComponent = entity.Background
    local backgroundId = backgroundComponent.Background
    local background = Ext.StaticData.Get(backgroundId, Ext.Enums.ExtResourceManagerType.Background)
    if background then
        if background.Passives == passiveId then
            return true
        end
    end

    -- Check if the passive was granted by an E6 feat, in which case we can include it.
    local e6Feats = entity.Vars.E6_Feats
    if not e6Feats then
        return false
    end
    for _, feat in ipairs(e6Feats) do
        if feat.PassivesAdded then
            for _,passive in ipairs(feat.PassivesAdded) do
                if passive == passiveId then
                    return true
                end
            end
        end
    end
    return false
end

---Determines if the ability score boost should be included in the ability scores for the character.
---@param entity EntityHandle The character entity
---@param boost EntityHandle The boost instance
---@param boostInfo BoostInfoComponent? The boost info component
---@return string? The name of the ability
---@return string? The cause of the boost
---@return integer? The delta value of the boost
---@return integer? The delta maximum of the boost
local function IncludeAbilityScoreBoost(entity, boost, boostInfo)
    if not IsValidCause(entity, boost, boostInfo) then
        return nil
    end

    ---@type AbilityBoostComponent?
    local ability = boost.AbilityBoost
    if not ability or not ability.Ability or not ability.Ability.Label then
        return nil
    end
    local abilityLabel = ability.Ability.Label
    local value = ability.Value
    local max = ability.field_8 -- TODO: This field will likely get renamed in the future
    local cause = boostInfo.Cause.Type.Label
    return abilityLabel, cause, value, max
end

---Gathers the ability scores from the ability boosts.
---@param entity EntityHandle The character entity handle
---@param boosts EntityHandle There isn't a specific type for the boost container, so we'll just use the entity handle.
---@return table? The ability scores and their maximums, or nil if it could not be determined.
local function GatherAbilityScoresFromBoosts(entity, boosts)
    if boosts == nil then
        return nil
    end

    local scores = {}
    for boostIndex,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        local abilityLabel, cause, value, max = IncludeAbilityScoreBoost(entity, boost, boostInfo)
        if abilityLabel then
            if not scores[abilityLabel] then
                scores[abilityLabel] = {Current = 0, Maximum = 20}
            end
            _E6P("Found ability boost [" .. tostring(boostIndex) .. "] " .. abilityLabel .. " (" .. cause .. "): amount delta=" .. tostring(value) .. ", max delta=" .. tostring(max))
            scores[abilityLabel].Current = scores[abilityLabel].Current + value
            scores[abilityLabel].Maximum = scores[abilityLabel].Maximum + max
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
    for _,boost in ipairs(boosts) do
        if boost.Type and boost.Type.Label == "Ability" then
            return GatherAbilityScoresFromBoosts(entity, boost.Boosts)
        end
    end
    return nil
end

---Gathers the proficiencies from the proficiency boosts.
---@param entity EntityHandle The character entity handle
---@param boosts EntityHandle There isn't a specific type for the boost container, so we'll just use the entity handle.
---@param proficiencies table The proficiency table to update
local function GatherProficienciesFromBoosts(entity, boosts, proficiencies)
    if boosts == nil then
        return
    end

    for _,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        if IsValidCause(entity, boost, boostInfo) and boost.ProficiencyBonusBoost then
            local proficiency = boost.ProficiencyBonusBoost
            if proficiency.Type.Label == "SavingThrow" then -- Saving throw
                local ability = proficiency.Ability.Label
                table.insert(proficiencies.SavingThrows, ability)
            elseif proficiency.Type.Label == "Skill" then -- Skill
                local skill = proficiency.Skill.Label
                proficiencies.Skills[skill] = {Proficient = true}
            end
        end
    end
end

---Gathers the expertise from the expertise boosts.
---@param entity EntityHandle The character entity handle
---@param boosts EntityHandle There isn't a specific type for the boost container, so we'll just use the entity handle.
---@param proficiencies table The proficiency table to update
local function GatherExpertiseFromBoosts(entity, boosts, proficiencies)
    if boosts == nil then
        return
    end

    for _,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        if IsValidCause(entity, boost, boostInfo) and boost.ExpertiseBonusBoost then
            local expertise = boost.ExpertiseBonusBoost
            if expertise then -- Expertise
                local skill = expertise.Skill.Label
                proficiencies.Skills[skill].Expertise = true -- The character should already have proficiency in the skill, initializing this.
            end
        end
    end
end

---Gathers the ability scores for the given character, without magical modifications
---@param entity EntityHandle
---@return table?
local function GatherProficiencies(entity)
    local boostContainer = entity.BoostsContainer
    if boostContainer == nil then
        return nil
    end
    local boosts = boostContainer.Boosts
    if boosts == nil then
        return nil
    end
    -- table structure
    -- {
    --   "SavingThrows": [<attributes>],
    --   "Skills": {
    --     "<name>": {Proficient = true/false, Expertise = true/false}
    --   }
    -- }
    -- Proficiency for saving throws and skills are stored in the ProficiencyBonus boosts.
    -- Expertise is stored in the ExpertiseBonus boosts.
    local proficiencies = {
        SavingThrows = {},
        Skills = {}
    }
    for _,boost in ipairs(boosts) do
        if boost.Type and boost.Type.Label == "ProficiencyBonus" then
            GatherProficienciesFromBoosts(entity, boost.Boosts, proficiencies)
        elseif boost.Type and boost.Type.Label == "ExpertiseBonus" then
            GatherExpertiseFromBoosts(entity, boost.Boosts, proficiencies)
        end
    end
    return proficiencies
end

local function SaveCharacterData(ent)
    --E6_ToFile(ent, "E6_Character.json", {"ProgressionContainer", "Party", "ServerReplicationDependencyOwner", "InventoryContainer"})
end

---Handles when the Epic6 Feat spell is cast to bring up the UI on the client to select a feat.
---@param caster string
local function OnEpic6FeatSelectorSpell(caster)
    local ent = Ext.Entity.Get(caster)
    local charname = GetCharacterName(ent)

    SaveCharacterData(ent)

    _E6P(EpicSpellContainerName .. " was cast by " .. charname .. " (" .. caster .. ")")

    local playerFeats = GatherPlayerFeats(ent)
    local abilityScores = GatherAbilityScores(ent)
    local proficiencies = GatherProficiencies(ent)
    local message = {
        PlayerId = caster,
        PlayerName = GetCharacterName(ent),
        PlayerFeats = playerFeats,
        PlayerPassives = GatherPlayerPassives(ent),
        SelectableFeats = GatherSelectableFeatsForPlayer(ent, playerFeats, { AbilityScores = abilityScores, Proficiencies = proficiencies }),
        Abilities = abilityScores, -- we need their current scores and maximums to display UI
        Proficiencies = proficiencies, -- gathered so we know what they are proficient in and what could be granted
        ProficiencyBonus = ent.Stats.ProficiencyBonus -- to show skill bonuses
    }

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