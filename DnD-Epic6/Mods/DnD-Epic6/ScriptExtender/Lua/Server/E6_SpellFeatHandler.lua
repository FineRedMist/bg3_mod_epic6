
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

    ---@type SelectedFeatType[]
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
---@param entity EntityHandle The player entity to test against.
---@param playerFeats table The feats the player already has.
---@param playerInfo table Information about what the player has for abilities, proficiencies, etc.
---@return string[] The collection of feats the player can actually select
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
    if cause == "CharacterCreation" or cause == "Progression" or causeInfo.Cause == "E6_Feat" then
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
    ---@type ResourceBackground
    local background = Ext.StaticData.Get(backgroundId, Ext.Enums.ExtResourceManagerType.Background)
    if background then
        if background.Passives == passiveId then
            return true
        end
    end

    -- Check if the passive was granted by an E6 feat, in which case we can include it.
    ---@type SelectedFeatType[]
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
    local max = ability.ValueCap
    local cause = boostInfo.Cause.Type.Label
    return abilityLabel, cause, value, max
end

---Gathers the ability scores from the ability boosts.
---@param entity EntityHandle The character entity handle
---@param boosts EntityHandle There isn't a specific type for the boost container, so we'll just use the entity handle.
---@return table<string, AbilityScoreType>? The ability scores and their maximums, or nil if it could not be determined.
local function GatherAbilityScoresFromBoosts(entity, boosts)
    if boosts == nil then
        return nil
    end

    ---@type table<string, AbilityScoreType>
    local scores = {}
    for boostIndex,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        local abilityLabel, cause, value, max = IncludeAbilityScoreBoost(entity, boost, boostInfo)
        if abilityLabel then
            if not scores[abilityLabel] then
                scores[abilityLabel] = {Current = 0, Maximum = 20}
            end
            scores[abilityLabel].Current = scores[abilityLabel].Current + value
            scores[abilityLabel].Maximum = scores[abilityLabel].Maximum + max
        end
    end
    return scores
end

---Gathers the ability scores for the given character, without magical modifications
---@param entity EntityHandle
---@return table<string, AbilityScoreType>?
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
---@param proficiencies ProficiencyInformationType The proficiency table to update
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
                proficiencies.SavingThrows[ability] = true
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
---@param proficiencies ProficiencyInformationType The proficiency table to update
local function GatherExpertiseFromBoosts(entity, boosts, proficiencies)
    if boosts == nil then
        return
    end

    for _,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        if IsValidCause(entity, boost, boostInfo) then
            local expertise = boost.ExpertiseBonusBoost
            if expertise then -- Expertise
                local skill = expertise.Skill.Label
                proficiencies.Skills[skill].Expertise = true -- The character should already have proficiency in the skill, initializing this.
            end
        end
    end
end

local EquipmentCategories = {
    SimpleWeapons = {"clubs", "daggers", "greatclubs", "handaxes", "javelins", "lighthammers", "maces", "quarterstaffs", "sickles", "spears", "lightcrossbows", "darts", "shortbows", "slings"},
    MartialWeapons = {"battleaxes", "flails", "glaives", "greataxes", "greatswords", "halberds", "lances", "longswords", "mauls", "morningstars", "pikes", "rapiers", "scimitars", "shortswords", "tridents", "warpicks", "warhammers", "whips", "blowguns", "handcrossbows", "heavycrossbows", "longbows", "nets"}
}
---Gathers proficiencies for equipment from the proficiency boosts.
---@param entity EntityHandle The character entity handle
---@param boosts EntityHandle There isn't a specific type for the boost container, so we'll just use the entity handle.
---@param proficiencies ProficiencyInformationType The proficiency table to update
local function GatherOtherProficiencesFromBoosts(entity, boosts, proficiencies)
    if boosts == nil then
        return
    end

    for _,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        if IsValidCause(entity, boost, boostInfo) and boost.ProficiencyBoost then
            local proficiencyFlags = boost.ProficiencyBoost.Flags
            for _,proficiency in ipairs(proficiencyFlags) do
                proficiencies.Equipment[string.lower(proficiency)] = true
                local category = EquipmentCategories[proficiency]
                if category then
                    for _,item in ipairs(category) do
                        proficiencies.Equipment[item] = true
                    end
                end
            end
        end
    end
end


---Gathers the ability scores for the given character, without magical modifications
---@param entity EntityHandle
---@return ProficiencyInformationType?
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
        Skills = {},
        Equipment = {}
    }
    for _,boost in ipairs(boosts) do
        if boost.Type and boost.Type.Label == "ProficiencyBonus" then
            GatherProficienciesFromBoosts(entity, boost.Boosts, proficiencies)
        elseif boost.Type and boost.Type.Label == "ExpertiseBonus" then
            GatherExpertiseFromBoosts(entity, boost.Boosts, proficiencies)
        else if boost.Type and boost.Type.Label == "Proficiency" then
            GatherOtherProficiencesFromBoosts(entity, boost.Boosts, proficiencies)
        end
        end
    end
    return proficiencies
end

local function GatherSpells(entity)
    local result = { Added = {}, Selected = {} }
    local cc = entity.CCLevelUp
    if not cc then
        return result
    end
    local levelUps = cc.LevelUps
    if not levelUps then
        return result
    end

    local function GetSpellResultList(listId)
        local spellResults = result.Selected[listId]
        if not spellResults then
            spellResults = {}
            result.Selected[listId] = spellResults
        end
        return spellResults
    end

    local function RemoveSpellFromList(resultList, spellName)
        resultList[spellName] = nil
    end

    local function AddSpellToList(resultList, spellName)
        resultList[spellName] = true
    end

    ---Adds the spell to the spellList, mapping class -> {classID, spells[]}
    ---@param levelup LevelUpData
    local function AddSpell(levelup)
        local upgrades = levelup.Upgrades
        if not upgrades then
            return
        end
        local upgradeSpells = upgrades.Spells
        if not upgradeSpells then
            return
        end
        for _,spellData in ipairs(upgradeSpells) do
            local list = spellData.SpellList
            if IsValidGuid(list) then
                local spells = spellData.Spells
                local replaceSpells = spellData.ReplaceSpells
                if replaceSpells then
                    local spellResults = GetSpellResultList(list)
                    for _,spell in ipairs(replaceSpells) do
                        RemoveSpellFromList(spellResults, spell.From)
                        AddSpellToList(spellResults, spell.To)
                    end
                end
                if spells then
                    local spellResults = GetSpellResultList(list)
                    for _,spell in ipairs(spells) do
                        AddSpellToList(spellResults, spell)
                    end
                end
            end
        end
    end

    local classInfos = {}
    ---@param levelup LevelUpData
    local function AddClassLevelUp(levelup)
        local classId = levelup.Class
        local subClassId = levelup.SubClass
        if not classInfos[classId] then
            classInfos[classId] = { Class = classId, Level = 0 }
        end
        local class = classInfos[classId]
        class.Level = class.Level + 1
        if IsValidGuid(subClassId) then
            class.SubClass = subClassId
        end
    end

    for _,levelup in ipairs(levelUps) do
        -- Gather class info to check progressions for granted spell categories
        AddClassLevelUp(levelup)
        -- Add the spells explicitly chosen
        AddSpell(levelup)
    end

    -- Gather progression data to compare against the classes
    -- Group by TableUUID
    local progressions = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.Progression)
    local progressionTables = {}
    for _,progressionId in ipairs(progressions) do
        ---@type ResourceProgression
        local progression = Ext.StaticData.Get(progressionId, Ext.Enums.ExtResourceManagerType.Progression)
        local pTable = progressionTables[progression.TableUUID]
        if not pTable then
            pTable = {}
            progressionTables[progression.TableUUID] = pTable
        end
        local progressionInfo = {Level = progression.Level, Added = {}}
        local addedSpells = progression.AddSpells
        local hasAdds = false
        for _, addSpell in ipairs(addedSpells) do
            progressionInfo.Added[addSpell.SpellUUID] = true
            hasAdds = true
        end
        if hasAdds then
            table.insert(pTable, progressionInfo)
        end
    end

    -- Now go through the classes and compare against the progression data.
    for classId, classInfo in pairs(classInfos) do
        local ids = { classId, classInfo.SubClass}
        for _, id in ipairs(ids) do
            if id and IsValidGuid(id) then
                ---@type ResourceClassDescription
                local class = Ext.StaticData.Get(classId, Ext.Enums.ExtResourceManagerType.ClassDescription)
                local progressionId = class.ProgressionTableUUID
                if IsValidGuid(progressionId) then
                    local pTable = progressionTables[progressionId]
                    for _, progressionInfo in ipairs(pTable) do
                        if progressionInfo.Level <= classInfo.Level then
                            for spellId,_ in pairs(progressionInfo.Added) do
                                result.Added[spellId] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- Add information from the E6 Feats
    ---@type SelectedFeatType[]
    local e6Feats = entity.Vars.E6_Feats
    if e6Feats ~= nil then
        for _, feat in ipairs(e6Feats) do
            local addedSpells = feat.AddedSpells
            if addedSpells then
                for _, listId in ipairs(addedSpells) do
                    result.Added[listId] = true
                end
            end
            local selectedSpells = feat.SelectedSpells
            if selectedSpells then
                for listId, spells in pairs(selectedSpells) do
                    local spellResults = GetSpellResultList(listId)
                    for _,spell in ipairs(spells) do
                        AddSpellToList(spellResults, spell)
                    end
                end
            end
        end
    end

    return result
end

---Handles when the Epic6 Feat spell is cast to bring up the UI on the client to select a feat.
---@param caster string
local function OnEpic6FeatSelectorSpell(caster)
    ---@type EntityHandle
    local ent = Ext.Entity.Get(caster)
    local charname = GetCharacterName(ent)

    local playerFeats = GatherPlayerFeats(ent)
    local abilityScores = GatherAbilityScores(ent)
    local proficiencies = GatherProficiencies(ent)
    local spells = GatherSpells(ent)

    ---@type PlayerInformationType
    local message = {
        ID = caster,
        Name = charname,
        PlayerFeats = playerFeats,
        PlayerPassives = GatherPlayerPassives(ent),
        SelectableFeats = GatherSelectableFeatsForPlayer(ent, playerFeats, { AbilityScores = abilityScores, Proficiencies = proficiencies }),
        Abilities = abilityScores, -- we need their current scores and maximums to display UI
        Proficiencies = proficiencies, -- gathered so we know what they are proficient in and what could be granted
        Spells = spells, -- The mapping of class to spell list.
        ProficiencyBonus = ent.Stats.ProficiencyBonus -- to show skill bonuses
    }

    local str = Ext.Json.Stringify(message)

    Ext.Net.PostMessageToClient(caster, NetChannels.E6_SERVER_TO_CLIENT_SHOW_FEAT_SELECTOR, str)
end

function E6_SpellFeatHandlerInit()
    Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function (caster, spell, _, _, _)
        if spell == EpicSpellContainerName then
            OnEpic6FeatSelectorSpell(caster)
        end
    end)
end