
---@type table<GUIDSTRING, string> mapping of class GUID to class name.
local classNameCache = {}

local function GetClassName(classId)
    local value = classNameCache[classId]
    if value then
        return value
    end

    ---@type ResourceClassDescription
    local class = Ext.StaticData.Get(classId, Ext.Enums.ExtResourceManagerType.ClassDescription)
    if class then
        classNameCache[classId] = class.Name
        return class.Name
    end

    _E6Error("Failed to lookup the class name for id: " .. classId)
    return "unknown"
end

---We need to gather feats that have already been selected for the entity so we can filter if necessary.
---@param entity EntityHandle The player entity to gather feats for.
---@return table<string, number> The count of occurrences for each feat. 
local function GatherPlayerClassLevels(entity)
    local levels = {}
    if entity == nil then
        return levels
    end
    local CCLevelUp = entity.CCLevelUp
    if CCLevelUp == nil then
        return levels
    end
    local function AddLevel(class)
        if IsValidGuid(class) then
            local className = GetClassName(class)
            local curCount = levels[className]
            if curCount == nil then
                curCount = 1
            else
                curCount = curCount + 1
            end
            levels[className] = curCount
        end
    end

    for _, levelup in ipairs(CCLevelUp.LevelUps) do
        AddLevel(levelup.Class)
    end
    return levels
end

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

---@type table<GUIDSTRING, string> Mapping of tag GUID to tag name.
local tagNameCache = {}

---Gathers class tags and converts them to the corresponding passives to filter from selection for the player.
---@param entity EntityHandle The character
---@param addPassive function Method to add passives to the list.
local function GatherPlayerTags(entity, addPassive)
    if entity == nil then
        return
    end

    local function ToPassiveName(tagName)
        local passiveName = "E6_Tag_" .. tagName .. "_Passive"
        addPassive(passiveName)
    end

    local function ProcessTags(tags)
        if tags == nil then
            return
        end

        for _,tag in pairs(tags) do
            if not tagNameCache[tag] then
                ---@type ResourceTag
                local tagResource = Ext.StaticData.Get(tag, Ext.Enums.ExtResourceManagerType.Tag)

                tagNameCache[tag] = ToPassiveName(NormalizePascalCase(tagResource.Name))
            end
            addPassive(tagNameCache[tag])
        end
    end

    if not entity.Tag then
        return
    end
    ProcessTags(entity.Tag.Tags)
end

---Gathers saving throws and converts them to the corresponding passives to filter from selection for the player.
---@param proficiencies ProficiencyInformationType The proficiency information for the player.
---@param addPassive function Method to add passives to the list.
local function GatherPlayerSavingThrows(proficiencies, addPassive)
    if not proficiencies or not proficiencies.SavingThrows then
        return
    end
    for savingThrow, _ in pairs(proficiencies.SavingThrows) do
        local passiveName = "Resilient_" .. savingThrow
        addPassive(passiveName)
    end
end

---We need to gather passives that have already been selected for the entity so we can filter if necessary.
---@param entity EntityHandle The player entity to gather passives for.
---@param proficiencies ProficiencyInformationType The proficiency information for the player.
---@return table<string, number> The count of occurrences for each passive. 
local function GatherPlayerPassives(entity, proficiencies)
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
        if playerPassive and (not playerPassive.Source or playerPassive.Source.ProgressionMeta) then
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

    -- Gather the tags from classes and emulate the E6_Tag_<target>_Passive passives to property
    -- exclude them from the list.
    GatherPlayerTags(entity, AddPassive)
    GatherPlayerSavingThrows(proficiencies, AddPassive)
    
    return passives
end

---Whether the current entity is a mind flayer player
---@param entity EntityHandle The character entity
---@return boolean True if the entity is a mind flayer player, false otherwise.
local function IsMindFlayerPlayer(entity)
    if entity == nil then
        return false
    end
    local shapeshiftStates = entity.ServerShapeshiftStates
    if shapeshiftStates == nil then
        _E6P("IsMindFlayerPlayer: " .. GetCharacterName(entity) .. " has no server shapeshift component.")
        return false
    end
    local states = shapeshiftStates.States
    if states == nil or #states == 0 then
        _E6P("IsMindFlayerPlayer: " .. GetCharacterName(entity) .. " has no shapeshift states.")
        return false
    end
    for _, s in ipairs(states) do
        if s.RootTemplate ~= nil and s.RootTemplate.RootTemplate == "ba20ee39-92ed-4aad-830d-4871103f48c2" then
            _E6P("IsMindFlayerPlayer: " .. GetCharacterName(entity) .. " is a mind flayer player.")
            return true
        elseif s.RootTemplate ~= nil and s.RootTemplate.RootTemplate == "ba20ee39-92ed-4aad-830d-4871103f48c2" then
            _E6P("IsMindFlayerPlayer: " .. GetCharacterName(entity) .. " has server shapeshift root template: " .. tostring(s.RootTemplate.RootTemplate))
        end
    end
    _E6P("IsMindFlayerPlayer: " .. GetCharacterName(entity) .. " didn't have the mind flayer player root template.")
    return false
end

---Determines if the boost should be included for the character.
---@param entity EntityHandle The character entity
---@param boost EntityHandle The boost instance
---@param boostInfo BoostInfoComponent? The boost info component
---@param isAbility boolean? True if this is an ability score boost, false or nil otherwise.
---@return boolean True if the boost should be included, false otherwise.
local function IsValidCause(entity, boost, boostInfo, isAbility)
    if not boostInfo then 
        return false
    end
    if not boostInfo.Cause then
        return false
    end
    local causeInfo = boostInfo.Cause
    local cause = causeInfo.Type.Label
    if causeInfo.Cause == "E6_Feat" then
        return true
    end
    -- If this is not an ability score boost, and it is from character creation or progression, we include it.
    -- If this is an ability score boost, only include it if the entity is not a mind flayer player and it is from character creation or progression.
    if (not isAbility or not IsMindFlayerPlayer(entity)) and (cause == "CharacterCreation" or cause == "Progression") then
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
---@return AbilityScoreType? The value of the boost
local function IncludeAbilityScoreBoost(entity, boost, boostInfo)
    if not IsValidCause(entity, boost, boostInfo, true) then
        return nil
    end

    ---@type AbilityBoostComponent?
    local ability = boost.AbilityBoost
    if not ability or not ability.Ability or not ability.Ability.Label then
        return nil
    end
    local abilityLabel = ability.Ability.Label
    local value = ability.Value
    ---@type number?
    local max = ability.ValueCap
    if max and max == 0 then
        max = nil
    end
    local cause = boostInfo.Cause.Type.Label
    return abilityLabel, cause, { Current = value, Maximum = max }
end

---Gathers the ability scores from the ability boosts.
---@param entity EntityHandle The character entity handle
---@param boosts EntityHandle There isn't a specific type for the boost container, so we'll just use the entity handle.
---@return table<string, AbilityScoreType> The ability scores and their maximums, or nil if it could not be determined.
local function GatherAbilityScoresFromBoosts(entity, boosts)
    if boosts == nil then
        return {}
    end

    local scores = {}

    ---If we are the mind flayer player, add its base ability scores instead of the character creation ones.
    ---We retrieve the mind flayer data in case it is overridden by another mod.
    if IsMindFlayerPlayer(entity) then
        ---@type Character
        local mindFlayer = Ext.Stats.Get("MindFlayer_Player", -1, true, true)
        if mindFlayer then
            scores["Strength"] = {Current =  tonumber(mindFlayer.Strength), Maximum = 20}
            scores["Dexterity"] = {Current =  tonumber(mindFlayer.Dexterity), Maximum = 20}
            scores["Constitution"] = {Current =  tonumber(mindFlayer.Constitution), Maximum = 20}
            scores["Intelligence"] = {Current =  tonumber(mindFlayer.Intelligence), Maximum = 20}
            scores["Wisdom"] = {Current =  tonumber(mindFlayer.Wisdom), Maximum = 20}
            scores["Charisma"] = {Current =  tonumber(mindFlayer.Charisma), Maximum = 20}
            _E6P("Mind Flayer stats: Str=" .. mindFlayer.Strength .. " Dex=" .. mindFlayer.Dexterity .. " Con=" .. mindFlayer.Constitution .. " Int=" .. mindFlayer.Intelligence .. " Wis=" .. mindFlayer.Wisdom .. " Cha=" .. mindFlayer.Charisma)
        else
            _E6P("Failed to retrieve the mind flayer player data, using the default values.")
        end
    end

    ---@type table<string, AbilityScoreType>
    for _,boost in ipairs(boosts) do
        ---@type BoostInfoComponent?
        local boostInfo = boost.BoostInfo
        local abilityLabel, cause, score = IncludeAbilityScoreBoost(entity, boost, boostInfo)
        if abilityLabel and score then
            _E6P("Adding ability score from " .. cause .. ": " .. abilityLabel .. " Current=" .. tostring(score.Current) .. ", Maximum=" .. tostring(score.Maximum))
            if not scores[abilityLabel] then
                scores[abilityLabel] = {Current = 0, Maximum = 20}
            end

            scores[abilityLabel] = MergeAbilityBoost(scores[abilityLabel], score)
        end
    end
    return scores
end

---Gathers the ability scores for the given character, without magical modifications
---@param entity EntityHandle The character entity handle
---@return table<string, AbilityScoreType> The ability scores and their maximums, or the empty set if it could not be determined.
local function GatherAbilityScores(entity)
    local boostContainer = entity.BoostsContainer
    if boostContainer == nil then
        return {}
    end
    local boosts = boostContainer.Boosts
    if boosts == nil then
        return {}
    end
    for _,boost in ipairs(boosts) do
        if boost.Type and boost.Type.Label == "Ability" then
            return GatherAbilityScoresFromBoosts(entity, boost.Boosts)
        end
    end
    return {}
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
                if proficiencies.Skills[skill] then -- After a respec, we get some odd lingering entries.
                    proficiencies.Skills[skill].Expertise = true
                end
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
---@param entity EntityHandle The character entity handle
---@return ProficiencyInformationType The proficiency information (skills, saving throws, weapons, armour, items), or EMPTY if it could not be determined.
local function GatherProficiencies(entity)
    local boostContainer = entity.BoostsContainer
    if boostContainer == nil then
        return {}
    end
    local boosts = boostContainer.Boosts
    if boosts == nil then
        return {}
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
    ---@type ProficiencyInformationType
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

---Gathers spells for the player
---@param entity EntityHandle
---@return table
local function GatherSpells(entity)
    ---@type SelectedSpellsType
    local result = { Added = {}, Selected = {} }
    local cc = entity.CCLevelUp
    if not cc then
        return result
    end
    local levelUps = cc.LevelUps
    if not levelUps then
        return result
    end

    ---@type SpellGrantMapType -- Maps the source id to the grant info
    local sourceGrantMap = {}

    -- Gather the spell grant info
    for _, spell in ipairs(entity.SpellContainer.Spells) do
        local spellId = spell.SpellId
        if spellId and not sourceGrantMap[spellId.ProgressionSource] then
            sourceGrantMap[spellId.ProgressionSource] = {SourceId = spellId.ProgressionSource, ResourceId = spell.PreferredCastingResource, AbilityId = spell.SpellCastingAbility.Label, PrepareType = spell.LearningStrategy, CooldownType = spell.CooldownType}
        end
    end

    local function GetSpellResultList(listId)
        local spellResults = result.Selected[listId]
        if not spellResults then
            spellResults = {}
            result.Selected[listId] = spellResults
        end
        return spellResults
    end

    local function GrantsEqual(a, b)
        return a.SourceId == b.SourceId and a.ResourceId == b.ResourceId and a.AbilityId == b.AbilityId
    end

    ---comment
    ---@param resultList SpellGrantMapType
    ---@param spellName string
    ---@param sourceId GUIDSTRING
    local function RemoveSpellFromList(resultList, spellName, sourceId)
        if not spellName or string.len(spellName) == 0 then
            return
        end
        local list = resultList[spellName]
        local inGrant = sourceGrantMap[sourceId]
        if not list then
            _E6Error("Could not remove the spell " .. spellName .. " from the list as it does not exist.")
            return
        end
        for i = #list, 1, -1 do
            local curGrant = list[i]
            if GrantsEqual(curGrant, inGrant) then
                table.remove(list, i)
                return
            end
        end
    end

    ---@param resultList SpellGrantMapType
    ---@param spellName string
    ---@param grantInfo SpellGrantInformationType
    local function AddSpellGrantToList(resultList, spellName, grantInfo)
        if not spellName or string.len(spellName) == 0 then
            return
        end
        local list = resultList[spellName]
        if not list then
            list = {}
            resultList[spellName] = list
        end
        list[#list+1] = grantInfo
    end

    ---@param resultList SpellGrantMapType
    ---@param spellName string
    ---@param sourceId GUIDSTRING
    local function AddSpellToList(resultList, spellName, sourceId)
        AddSpellGrantToList(resultList, spellName, sourceGrantMap[sourceId])
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
                local sourceId = spellData.Class
                if replaceSpells then
                    local spellResults = GetSpellResultList(list)
                    for _,spell in ipairs(replaceSpells) do
                        RemoveSpellFromList(spellResults, spell.From, sourceId)
                        AddSpellToList(spellResults, spell.To, sourceId)
                    end
                end
                if spells then
                    local spellResults = GetSpellResultList(list)
                    for _,spell in ipairs(spells) do
                        AddSpellToList(spellResults, spell, sourceId)
                    end
                end
            end
        end
    end

    -- Gather how many levels I have of each class
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
    
    ---@class ProgressionSpellInfoType
    ---@field Level integer The progression level
    ---@field Added table<GUIDSTRING, SpellGrantInformationType> The spells added at this level

    ---@type table<GUIDSTRING, ProgressionSpellInfoType[]>
    local progressionTables = {}
    for _,progressionId in ipairs(E6_GetCachedProgressionIds()) do
        ---@type ResourceProgression
        local progression = Ext.StaticData.Get(progressionId, Ext.Enums.ExtResourceManagerType.Progression)
        local pTable = progressionTables[progression.TableUUID]
        if not pTable then
            pTable = {}
            progressionTables[progression.TableUUID] = pTable
        end

        ---@type ProgressionSpellInfoType
        local progressionInfo = {Level = progression.Level, Added = {}}
        local addedSpells = progression.AddSpells
        local hasAdds = false
        for _, addSpell in ipairs(addedSpells) do
            progressionInfo.Added[addSpell.SpellUUID] = {SourceId = addSpell.ClassUUID, ResourceId = addSpell.ActionResource, AbilityId = addSpell.Ability.Label, CooldownType = addSpell.CooldownType, PrepareType = addSpell.PrepareType}
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
            if IsValidGuid(id) then
                ---@type ResourceClassDescription
                local class = Ext.StaticData.Get(classId, Ext.Enums.ExtResourceManagerType.ClassDescription)
                local progressionId = class.ProgressionTableUUID
                if IsValidGuid(progressionId) then
                    local pTable = progressionTables[progressionId]
                    for _, progressionInfo in ipairs(pTable) do
                        if progressionInfo.Level <= classInfo.Level then
                            for spellId,grantInfo in pairs(progressionInfo.Added) do
                                local grant = DeepCopy(grantInfo)
                                result.Added[spellId] = grant
                                grant.SourceId = classId
                                grant.AbilityId = class.PrimaryAbility.Label
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
                for listId, grantInfo in pairs(addedSpells) do
                    result.Added[listId] = grantInfo
                end
            end
            local selectedSpells = feat.SelectedSpells
            if selectedSpells then
                for listId, spells in pairs(selectedSpells) do
                    local spellResults = GetSpellResultList(listId)
                    for spellId,grantInfo in pairs(spells) do
                        AddSpellGrantToList(spellResults, spellId, grantInfo)
                    end
                end
            end
        end
    end

    return result
end

---@param abilities table<string, AbilityScoreType>
local function GetAbilityModifierFromAbilities(abilities, abilityId)
    local ability = abilityId.Label
    if not ability then
        _E6Error("Failed to identify AbilityId to generate ability modifiers.")
        return 0
    end
    if not abilities[ability] then
        _E6Error("Ability " .. ability .. " not found in abilities.")
        return 0
    end
    local score = abilities[ability].Current
    if not score then
        return 0
    end
    return GetAbilityModifier(score)
end

---Gathers strings to resolve on the client.
---@param entityId GUIDSTRING
---@param abilities table<string, AbilityScoreType>
local function GatherResolverStringMap(entityId, abilities)
    local map = {}
    local function GetItem(kind)
        local id = Osi.GetEquippedItem(entityId, kind .. " Main Weapon")
        if not id then
            return
        end
        local ent = Ext.Entity.Get(id)
        if not ent then
            return
        end
        local damage, damageType, damageRange
        if ent.ServerBaseWeapon and ent.ServerBaseWeapon.DamageList and #ent.ServerBaseWeapon.DamageList > 0 then
            local first = ent.ServerBaseWeapon.DamageList[1]
            damageType = first.DamageType.Label
            if first.Roll then
                damage = tostring(first.Roll.AmountOfDices) .. "d" .. first.Roll.DiceValue.Label
                if first.Roll.DiceAdditionalValue then
                    damage = damage .. "+" .. tostring(first.Roll.DiceAdditionalValue)
                end
            end
        end
        if ent.Weapon then
            if ent.Weapon.Rolls and #ent.Weapon.Rolls > 0 then
                damage = ""
                for ability, rollSet in pairs(ent.Weapon.Rolls) do
                    for _, roll in ipairs(rollSet) do
                        damage = damage .. "+" .. tostring(roll.AmountOfDices) .. roll.DiceValue.Label
                        if roll.DiceAdditionalValue then
                            damage = damage .. "+" .. tostring(roll.DiceAdditionalValue)
                        end
                    end
                    local modifier = GetAbilityModifierFromAbilities(abilities, ability)
                    if modifier > 0 then
                        damage = damage .. "+" .. tostring(modifier)
                    else
                        damage = damage .. "-" .. tostring(math.abs(modifier))
                    end
                end
            end
            if ent.Weapon.WeaponRange then
                damageRange = ent.Weapon.WeaponRange
            end
        end

        if damage then
            map["Main" .. kind .. "Weapon"] = damage
            map["Main" .. kind .. "WeaponDamageType"] = damageType
            map[kind .. "MainWeaponRange"] = damageRange
        end
    end
    -- MainMeleeWeapon, MainMeleeWeaponDamageType, MeleeMainWeaponRange, RangedMainWeaponRange
    GetItem("Melee")
    GetItem("Ranged")
    return map
end

---Sends a message to the client corresponding to the given caster.
---@param caster GUIDSTRING
---@param playerInfo PlayerInformationType
local function SendShowFeatSelector(caster, playerInfo)
    local str = Ext.Json.Stringify(playerInfo)
    Ext.Net.PostMessageToClient(caster, NetChannels.E6_SERVER_TO_CLIENT_SHOW_FEAT_SELECTOR, str)
end

---Gathers the full player information for the given entity and returns the data.
---@param ent EntityHandle The entity to gather the information for.
---@param uuid GUIDSTRING The UUID of the entity.
---@param charname string The name of the character.
---@param isHost boolean True if the player is the host, false otherwise.
---@param featPoints integer The number of feat points the player has.
---@return PlayerInformationType
local function GetExtendedPlayerInfo(ent, uuid, charname, isHost, featPoints)
    local playerFeats = GatherPlayerFeats(ent)
    local abilityScores = GatherAbilityScores(ent)
    local proficiencies = GatherProficiencies(ent)
    local spells = GatherSpells(ent)
    local passives = GatherPlayerPassives(ent, proficiencies)
    local levels = GatherPlayerClassLevels(ent)

    ---@type PlayerFeatRequirementInformationType
    local featRequirementInfo = {
        PlayerLevels = levels,
        PlayerPassives = passives,
        PlayerFeats = playerFeats,
        Proficiencies = proficiencies,
        Abilities = abilityScores
    }

    local selectableFeats, filteredFeats = GatherSelectableFeatsForPlayer(ent, featRequirementInfo)

    ---@type PlayerInformationType
    return {
        UUID = uuid,
        Name = charname,
        PlayerLevels = levels,
        PlayerFeats = playerFeats,
        PlayerPassives = passives,
        SelectableFeats = selectableFeats,
        FilteredFeats = filteredFeats,
        Abilities = abilityScores, -- we need their current scores and maximums to display UI
        Proficiencies = proficiencies, -- gathered so we know what they are proficient in and what could be granted
        Spells = spells, -- The mapping of class to spell list.
        ProficiencyBonus = ent.Stats.ProficiencyBonus, -- to show skill bonuses
        XPPerFeat = GetEpicFeatXP(),
        XPPerFeatIncrease = GetEpicFeatXPIncrease(),
        IsHost = isHost,
        FeatPoints = featPoints,
        ResolveMap = GatherResolverStringMap(uuid, abilityScores)
    }
end

---Retrieves the full player info sent to the client for feat selection for diagnostics.
---@param ent EntityHandle The entity to gather the information for.
---@return PlayerInformationType? The player information, or nil if it could not be determined.
function GetFullPlayerInfo(ent)
    local uuid = GetEntityID(ent)
    if not uuid then
        return nil
    end
    local charname = GetCharacterName(ent)
    local isHost = IsHost(uuid)
    local featPoints = E6_GetFeatPointBoostAmount(uuid)
    return GetExtendedPlayerInfo(ent, uuid, charname, isHost, featPoints)
end

---Handles when the Epic6 Feat spell is cast to bring up the UI on the client to select a feat.
---@param caster string
function OnEpic6FeatSelectorSpell(caster)
    ---@type EntityHandle
    local ent = Ext.Entity.Get(caster)
    local charname = GetCharacterName(ent)

    local uuid = GetEntityID(ent)
    local isHost = IsHost(uuid)
    local featPoints = E6_GetFeatPointBoostAmount(uuid)
    -- Show the feat selector without any feats to show settings.
    if featPoints == 0 then
        ---@type PlayerInformationType
        local playerInfoLite = {
            UUID = uuid,
            Name = charname,
            PlayerFeats = {},
            PlayerLevels = {},
            PlayerPassives = {},
            SelectableFeats = {},
            FilteredFeats = {},
            Abilities = {}, -- we need their current scores and maximums to display UI
            Proficiencies = {}, -- gathered so we know what they are proficient in and what could be granted
            Spells = {Added={}, Selected={}}, -- The mapping of class to spell list.
            ProficiencyBonus = ent.Stats.ProficiencyBonus, -- to show skill bonuses
            XPPerFeat = GetEpicFeatXP(),
            XPPerFeatIncrease = GetEpicFeatXPIncrease(),
            IsHost = isHost,
            FeatPoints = featPoints,
            ResolveMap = {}
        }
        SendShowFeatSelector(caster, playerInfoLite)
        return
    end


    --_E6P("Player Info: " .. Ext.Json.Stringify(message))
    local message = GetExtendedPlayerInfo(ent, uuid, charname, isHost, featPoints)
    SendShowFeatSelector(caster, message)
end

function E6_SpellFeatHandlerInit()
    Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function (caster, spell, _, _, _)
        if spell == EpicSpellContainerName then
            OnEpic6FeatSelectorSpell(caster)
        end
    end)
end