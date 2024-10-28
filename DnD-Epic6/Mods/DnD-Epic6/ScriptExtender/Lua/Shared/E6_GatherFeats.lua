
---Returns true if the feat is supported, false otherwise.
---@param feat ResourceFeat The feat to check for support.
---@return string? nil if supported, a string indicating the reason if not supported.
local function E6_IsFeatSupported(feat)
    -- We don't support ability bonuses yet
    if feat.SelectAbilityBonus ~= nil and #feat.SelectAbilityBonus > 0 then
        return "the feat selects ability bonuses"
    end
    -- We don't support equipment yet
    if feat.SelectEquipment ~= nil and #feat.SelectEquipment > 0 then
        return "the feat selects equipment"
    end
    return nil
end

local featOverrideAllowMultiple = {}
featOverrideAllowMultiple["019564a0-f136-4139-94ea-040f94bbaf19"] = "Skilled"
featOverrideAllowMultiple["d10c01e5-50f9-4ffa-b20d-ffbfb89ab554"] = "SkillExpert"
featOverrideAllowMultiple["b13c4744-1d45-42da-b92c-e09f598ab1c3"] = "Resilient"
featOverrideAllowMultiple["08a88b82-3e78-4189-8996-15dcaaa676e3"] = "EldritchAdept"

---Adds a requirement for the feat.
---@param feat FeatType The feat to add the requirement to.
---@param testFunc function the function to test the requirement.
local function E6_AddFeatRequirement(feat, testFunc)
    if not feat.HasRequirements then
        feat.HasRequirements = { testFunc }
        return
    end
    table.insert(feat.HasRequirements, testFunc)
end

---@param message string The error message about the failure
---@param args any[]? Additional arguments to pass to the error message.
---@return FeatMessageType The message to display to the player about why the requirement failed.
local function ToMessageLoca(message, args)
    return { MessageLoca = message, Args = args }
end

local RequirementsMet = ToMessageLoca("h35115c97g6f5bg4ba5gad35gfdba5e7e1d51")

---Returns the loca for a missing ability.
---@param abilityName string The name of the ability that was missing.
---@return FeatMessageType The message to display to the player about why the requirement failed.
local function MissingAbilityLoca(abilityName)
    local isAbility = AbilityPassives[abilityName] ~= nil
    local param = abilityName
    if isAbility then
        param = AbilityPassives[abilityName].DisplayName
    end
    return ToMessageLoca("hbc4fc044gb46fg47f2g9ff9g00af57de9fae", {param}) -- The ability [1] could not be found on the character
end

---Indicates a match failure
---@param feat table The feat entry for the ability requirement
---@param errorMessage string The error message about the failure
---@param args any[] Additional arguments to pass to the error message.
---@return function That always returns false for match failures against the requirements of the feat.
local function E6_MatchFailure(feat, errorMessage, args)
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Always false
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        return false, { MessageLoca = errorMessage, Args = args }
    end
end

---Generates the function to test the character for meeting the ability requirement for selecting abilities. In particular, if the player has
---maxed out their abilities for all the selectable abilities, then prevent the feat from being selectable.
---@param feat FeatType The feat entry for the ability requirement
local function E6_ApplySelectAbilityRequirement(feat)
    if #feat.SelectAbilities == 0 then
        return
    end
    for _, ability in ipairs(feat.SelectAbilities) do
        ---@type ResourceAbilityList
        local abilityList = Ext.StaticData.Get(ability.SourceId, Ext.Enums.ExtResourceManagerType.AbilityList)
        if not abilityList then
            E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h33fcc5c5g2d0dg45a4ga313gc12dbfbb9ac7", ability.SourceId})) -- Feat misconfiguration: [1], The ability list [2] wasn't found.
            return
        end
        ---@type string[] The list of abilities in the ability list.
        local abilityNames = {}
        for _,abilityName in ipairs(abilityList.Abilities) do
            table.insert(abilityNames, abilityName.Label)
        end
        ---@param entity EntityHandle The entity to test the requirement against.
        ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
        ---@return boolean Whether the player meets the ability score requirement.
        ---@return FeatMessageType The message to display to the player about why the requirement failed.
        local abilityRequirement = function(entity, playerInfo)
            local abilityScores = playerInfo.Abilities
            -- Determine the total number of assignable points across the listed abilities. If the count is less than granted, return false.
            local availablePointRoom = 0
            for _,abilityName in ipairs(abilityNames) do
                local abilityScore = abilityScores[abilityName]
                if not abilityScore then
                    return false, MissingAbilityLoca(abilityName)
                end
                availablePointRoom = availablePointRoom + abilityScore.Maximum - abilityScore.Current
            end
            if availablePointRoom < ability.Count then
                return false, ToMessageLoca("h2e9bd450g5df3g4075ga81eg29eef9f9f4a4")
            end
            return true, RequirementsMet
        end
        E6_AddFeatRequirement(feat, abilityRequirement)
    end
end

---Generates the function to filter the feat if the character already has all the selectable passives.
---@param feat FeatType The feat entry for the ability requirement
local function E6_ApplySelectPassiveRequirement(feat)
    if #feat.SelectPassives == 0 then
        return
    end
    for _, passive in ipairs(feat.SelectPassives) do
        ---@type ResourcePassiveList
        local passiveList = Ext.StaticData.Get(passive.SourceId, Ext.Enums.ExtResourceManagerType.PassiveList)
        if not passiveList then
            E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h31df0045ge2e3g453bga538ga0a618a38844", passive.SourceId})) -- Feat misconfiguration: [1], The passive list [2] wasn't found.
            return
        end
        ---@type string[] The list of passives in the passive list.
        local passiveNames = {}
        for _,passiveName in ipairs(passiveList.Passives) do
            table.insert(passiveNames, passiveName)
        end

        -- Number of passives to choose.
        local passiveCount = passive.Count

        ---@param entity EntityHandle The entity to test the requirement against.
        ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
        ---@return boolean Whether the feat has enough passives remaining to select.
        ---@return FeatMessageType The message to display to the player about why the requirement failed.
        local passiveRequirement = function(entity, playerInfo)
            local playerPassives = playerInfo.PlayerPassives
            local missingPassives = 0
            for _,passiveName in ipairs(passiveNames) do
                if not playerPassives[passiveName] then
                    missingPassives  = missingPassives + 1
                end
                if missingPassives >= passiveCount then
                    return true, RequirementsMet
                end
            end
            return false, ToMessageLoca("h8b51336eg9283g49acgb856g30ab5c92524c")
        end
        E6_AddFeatRequirement(feat, passiveRequirement)
    end
end

---Generates the function to test the character for meeting the ability requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param abilityMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeAbilityRequirement(feat, abilityMatch)
    local ability = abilityMatch[1]
    local value = tonumber(abilityMatch[2])
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player meets the ability score requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        local abilityScores = playerInfo.Abilities
        if not abilityScores then
            return false, ToMessageLoca("h3ee30c4bg920fg46fdga857g21d9a21b5bb5") -- An error occurred getting the player's ability scores.
        end
        local abilityScore = abilityScores[ability]
        if not abilityScore then
            return false, MissingAbilityLoca(ability)
        end
        if abilityScore.Current >= value then
            return true, RequirementsMet
        end
        return false, ToMessageLoca("h69b3c062g4965g4fbeg9446g901d37a06d72", {AbilityPassives[ability].DisplayName, value, abilityScore.Current}) -- [1] is less than [2]. It is currently [3].
    end
end

---Generates the function to test the character for meeting the proficiency requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeProficiencyRequirement(feat, proficiencyMatch)
    local proficiency = proficiencyMatch[1]
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player meets the ability score requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        if not ProficiencyLoca[proficiency] then
            return false, ToMessageLoca("h1c81aad6g23b0g4068ga108g3b4b0957050b", {proficiency}) -- Unknown proficiency: [1]
        end
        local proficiencyComp = entity.Proficiency
        if not proficiencyComp then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        local proficiencyFlags = proficiencyComp.Flags
        if proficiencyFlags == nil then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        for _,proficiencyFlag in ipairs(proficiencyFlags) do
            if proficiencyFlag == proficiency then
                return true, RequirementsMet
            end
        end
        return false, ToMessageLoca("h0772c666g159dg47eag857eg2c8bb25bc440", {ProficiencyLoca[proficiency]}) -- Missing proficiency: [1]
    end
end

---Generates the function to test the character for meeting the non-proficiency requirement specified.
---@param feat FeatType The feat entry for the non-proficiency requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the non-proficiency requirement, false otherwise.
local function E6_MakeNonProficiencyRequirement(feat, proficiencyMatch)
    local proficiency = proficiencyMatch[1]
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player has the proficiency requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        if not ProficiencyLoca[proficiency] then
            return false, ToMessageLoca("h1c81aad6g23b0g4068ga108g3b4b0957050b", {proficiency}) -- Unknown proficiency: [1]
        end
        local proficiencyComp = entity.Proficiency
        if not proficiencyComp then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        local proficiencyFlags = proficiencyComp.Flags
        if proficiencyFlags == nil then
            return false, ToMessageLoca("h54868782g1a0bg4f36g8e13gc6f4adfccfc4") -- An error occurred getting the player's proficiencies.
        end
        for _,proficiencyFlag in ipairs(proficiencyFlags) do
            if proficiencyFlag == proficiency then
                return false, ToMessageLoca("h1d87338fgc5ddg4386gaf1eg83c82d9ca1a3", {ProficiencyLoca[proficiency]}) -- Already has proficiency: [1]
            end
        end
        return true, RequirementsMet
    end
end

---Generates the function to test the character for meeting the proficiency requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakeCharacterLevelRequirement(feat, proficiencyMatch)
    local levelRequirement = tonumber(proficiencyMatch[1])
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the character level is strictly greater than the requirement.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        return entity.EocLevel.Level > levelRequirement, ToMessageLoca("h04fab965g7b1bg47fegad9bg69ae676c8cdf", {levelRequirement}) -- Character level must be greater than: [1]
    end
end


---Generates the function to test the character for meeting the passive requirement specified.
---@param feat FeatType The feat entry for the ability requirement
---@param proficiencyMatch string[] The matched requirement parameters from the requirement expression
---@return function That evaluates to true if the character meets the requirement, false otherwise.
local function E6_MakePassiveRequirement(feat, proficiencyMatch)
    local passiveName = proficiencyMatch[1]
    ---@param entity EntityHandle The entity to test the requirement against.
    ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
    ---@return boolean Whether the player has the passive.
    ---@return FeatMessageType The message to display to the player about why the requirement failed.
    return function(entity, playerInfo)
        ---@type PassiveData Data for the passive
        local passiveStat = Ext.Stats.Get(passiveName,  -1, true, true)
        if not passiveStat then
            return false, ToMessageLoca("h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h9d531312g1e6ag4dd9ga25ag405948ce70af", passiveName}) -- Feat misconfiguration: [1], The passive [2] wasn't found.
        end
        return playerInfo.PlayerPassives[passiveName] ~= nil, ToMessageLoca("hd7005e0bgad9bg43afgabb9gd831f1708f49", {passiveStat.DisplayName}) -- Missing ability: [1]
    end
end

local featRequirementRegexes = {
    {
        Regex = "FeatRequirementAbilityGreaterEqual%('(%w+)',(%d+)%)",
        Func = E6_MakeAbilityRequirement
    },
    {
        Regex = "FeatRequirementProficiency%('(%w+)'%)",
        Func = E6_MakeProficiencyRequirement
    },
    {
        Regex = "FeatRequirementNonProficiency%('(%w+)'%)",
        Func = E6_MakeNonProficiencyRequirement
    },
    {
        Regex = "CharacterLevelGreaterThan%((%d+)%)",
        Func = E6_MakeCharacterLevelRequirement
    },
    {
        Regex = "HasPassive%('(.+)'%)",
        Func = E6_MakePassiveRequirement
    },
    {
        Regex = "(.+)",
        Func = E6_MatchFailure
    }
}

---Adds the requirements the feat specifies to the feat entry.
---@param feat FeatType The feat entry to update
---@param spec ResourceFeat The specification table for the feat from Feats.lsx
local function E6_ApplyFeatRequirements(feat, spec)
    if spec.Requirements == nil then
        return
    end
    if string.len(spec.Requirements) == 0 then
        return
    end
    local requirements = SplitString(spec.Requirements, ";")
    for _, req in ipairs(requirements) do
        if string.len(req) > 0 then
            local matched = false
            for _,featReqRegex in ipairs(featRequirementRegexes) do
                local regex = featReqRegex.Regex
                local reqFunc = featReqRegex.Func
                local matchResult = GetFullMatch(req, regex)
                if matchResult then
                    E6_AddFeatRequirement(feat, reqFunc(feat, matchResult))
                    matched = true
                    break
                end
            end
            if not matched then
                E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "hf5f71dc3g2cd6g40ddga2aeg167bdfe6d71e", {req})) -- Unknown requirement (please report a bug on NexusMods for DnD-Epic6 to have it added): [1]
            end
        end
    end
end

---Gathers any ability modifiers from the passive ability boosts.
---Note: This will be used for both feats and for passives listed in the passive list for selection. 
---@param passiveName string Name of the passive to gather the ability modifiers from. 
---@return table<string,number>? A mapping of ability name to delta value.
local function GatherPassiveAbilityModifiers(passiveName)
    local result = {}
    ---@type PassiveData Data for the passive
    local passive = Ext.Stats.Get(passiveName, -1, true, true)
    --There is a passive in the list we can't get data for, indicate it is invalid and filter it out.
    if not passive then
        return nil
    end
    if passive and passive.Boosts then
        local boosts = SplitString(passive.Boosts, ";")
        for _,boost in ipairs(boosts) do
            local ability, delta = ParseAbilityBoost(boost)
            if ability then
                if not result[ability] then
                    result[ability] = delta
                else
                    result[ability] = result[ability] + delta
                end
            end
        end
    end
    return result
end

---Merges the ability boosts from the passive into the general ability boost table.
---@param abilityBoosts table<string,number>
---@param passiveBoosts table<string,number>
local function MergeAbilityBoosts(abilityBoosts, passiveBoosts)
    for ability,delta in pairs(passiveBoosts) do
        if not abilityBoosts[ability] then
            abilityBoosts[ability] = delta
        else
            abilityBoosts[ability] = abilityBoosts[ability] + delta
        end
    end
end

---Determines whether taking the feat will raise the player's abilities above the maximum
---@param feat FeatType The feat to test against
local function E6_ApplyFeatAbilityConstraints(feat)
    local abilityBoosts = {}
    local isValid = true
    local failedPassiveName = nil
    for _,passiveName in ipairs(feat.PassivesAdded) do
        local passiveBoosts = GatherPassiveAbilityModifiers(passiveName)
        if passiveBoosts then
            MergeAbilityBoosts(abilityBoosts, passiveBoosts)
        else
            failedPassiveName = passiveName
            isValid = false
        end
    end
    if not isValid then
        E6_AddFeatRequirement(feat, E6_MatchFailure(feat, "h5a0ed75fg8a79g4481g90e3g318669d0a6e7", {"h9d531312g1e6ag4dd9ga25ag405948ce70af", failedPassiveName})) -- Feat misconfiguration: [1], The passive [2] wasn't found.
        return
    end
    if next(abilityBoosts) ~= nil then
        ---@param entity EntityHandle The entity to test the requirement against.
        ---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
        ---@return boolean Whether the ability boosts of the feat are not going to exceed limits.
        ---@return FeatMessageType The message to display to the player about why the requirement failed.
        local function validateAbilityBoosts(entity, playerInfo)
            local abilityScores = playerInfo.Abilities
            for ability,delta in pairs(abilityBoosts) do
                local name = GetCharacterName(entity)
                if not abilityScores then
                    return false, ToMessageLoca("h3ee30c4bg920fg46fdga857g21d9a21b5bb5") -- An error occurred getting the player's ability scores.
                end
                local abilityScore = abilityScores[ability]
                if not abilityScore then
                    return false, MissingAbilityLoca(ability)
                end
                if abilityScore.Current + delta > abilityScore.Maximum then
                    return false, ToMessageLoca("h2e9bd450g5df3g4075ga81eg29eef9f9f4a4")
                end
            end
            return true, RequirementsMet
        end

        E6_AddFeatRequirement(feat, validateAbilityBoosts)
    end
end

---Applies overrides to feats to allow or constrain feats further.
---@param feat FeatType The feat entry to update
---@param spec ResourceFeat The specification table for the feat from Feats.lsx
local function E6_ApplyFeatOverrides(feat, spec)
    local featId = feat.ID
    if featOverrideAllowMultiple[featId] then
        feat.CanBeTakenMultipleTimes = true
    end

    E6_ApplyFeatAbilityConstraints(feat)
    E6_ApplySelectAbilityRequirement(feat)
    E6_ApplySelectPassiveRequirement(feat)
    E6_ApplyFeatRequirements(feat, spec)
end

---Processes a property list by applying a function to each element and returning a table of the results.
---@param sourceList table[]
---@param func function
---@return table
local function ProcessProperty(sourceList, func)
    local result = {}
    for _,source in ipairs(sourceList) do
        table.insert(result, func(source))
    end
    return result
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectAbilitiesType[] The list of passive options for the feat.
local function ProcessAbilities(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Arg2,
            Max = source.Arg3,
            Source = source.Arg4,
            SourceId = source.UUID
        }
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectSkillsType[] The list of passive options for the feat.
local function ProcessSkills(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Amount,
            Source = source.Arg3,
            SourceId = source.UUID
        }
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectSkillExpertiseType[] The list of passive options for the feat.
local function ProcessSkillExpertise(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Amount,
            Arg3 = source.Arg3,
            Source = source.Arg4,
            SourceId = source.UUID
        }
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList any The source information to convert.
---@return SelectPassiveType[] The list of passive options for the feat.
local function ProcessPassives(sourceList)
    return ProcessProperty(sourceList, function(source)
        return {
            Count = source.Amount,
            Unknown = source.Amount2,
            Arg3 = source.Arg3,
            SourceId = source.UUID
        }
    end)
end

---Converts the source object, extracting common core spell information for AddSpells and SelectSpells.
---@param source table The source object to convert.
---@return SelectSpellBaseType The common core spell information.
local function ProcessSpellBase(source)
    return {
        SpellsId = source.SpellUUID,
        ActionResource = source.ActionResource,
        PrepareType = source.PrepareType.Label,
        CooldownType = source.CooldownType.Label
    }
end

---Processes a passive list into the passive options for the feat.
---@param sourceList ResourceProgressionAddedSpell The source information to convert.
---@return AddSpellsType[] The list of passive options for the feat.
local function ProcessAddSpells(sourceList)
    return ProcessProperty(sourceList, function(source)
        ---@type AddSpellsType
        local result = ProcessSpellBase(source)
        result.Ability = source.Ability.Label
        if result.Ability == "None" then
            result.Ability = "Intelligence"
        end
        return result
    end)
end

---Processes a passive list into the passive options for the feat.
---@param sourceList ResourceProgressionSpell The source information to convert.
---@return SelectSpellsType[] The list of passive options for the feat.
local function ProcessSelectSpells(sourceList)
    return ProcessProperty(sourceList, function(source)
        ---@type SelectSpellsType
        local result = ProcessSpellBase(source)
        result.Ability = source.CastingAbility.Label
        result.Count = source.Amount
        if result.Ability == "None" then
            result.Ability = "Intelligence"
        end
        return result
    end)
end


---Creates a feat info object from the feat specification and description.
---@param featId GUIDSTRING The feat Id to create the feat info for.
---@param spec ResourceFeat The specification of the feat.
---@param desc table The description of the feat.
---@return FeatType The feat information object.
local function E6_MakeFeatInfo(featId, spec, desc)
    local passivesAdded = {}
    if spec.PassivesAdded then
        passivesAdded = SplitString(spec.PassivesAdded, ";")
    end

    ---@type FeatType
    local feat = {
        ID = featId,
        ShortName = spec.Name,
        DisplayName = Ext.Loca.GetTranslatedString(desc.DisplayName.Handle.Handle, desc.DisplayName.Handle.Version),
        Description = Ext.Loca.GetTranslatedString(desc.Description.Handle.Handle, desc.Description.Handle.Version),
        CanBeTakenMultipleTimes = spec.CanBeTakenMultipleTimes,
        HasRequirements = {},
        PassivesAdded = passivesAdded,
        SelectAbilities = ProcessAbilities(spec.SelectAbilities),
        SelectSkills = ProcessSkills(spec.SelectSkills),
        SelectSkillsExpertise = ProcessSkillExpertise(spec.SelectSkillsExpertise),
        SelectPassives = ProcessPassives(spec.SelectPassives),
        AddSpells = ProcessAddSpells(spec.AddSpells),
        SelectSpells = ProcessSelectSpells(spec.SelectSpells)
    }

    E6_ApplyFeatOverrides(feat, spec)
    return feat
end

local E6_FeatSet = nil

---Gathers feats from the game and converts them to a format that can be used by the E6 system.
---@return table<GUIDSTRING,FeatType> The mapping of feat ids to the feat information.
function E6_GatherFeats()
    if E6_FeatSet ~= nil then
        return E6_FeatSet
    end

    local featSet = {}
    E6_FeatSet = featSet

    local feats = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.Feat)
    for _, featid in ipairs(feats) do
        ---@type ResourceFeat The feat specification from the game.
        local feat = Ext.StaticData.Get(featid, Ext.Enums.ExtResourceManagerType.Feat)
        local featRejectReason = E6_IsFeatSupported(feat)
        if featRejectReason == nil then
            featSet[featid] = {Spec = feat}
        else
            _E6Warn("Skipping unsupported feat " .. feat.Name .. ": " .. featRejectReason)
        end
    end

    local featDescriptions = Ext.StaticData.GetAll(Ext.Enums.ExtResourceManagerType.FeatDescription)
    for _, descriptionid in ipairs(featDescriptions) do
        ---@type ResourceFeatDescription The feat specification from the game.
        local description = Ext.StaticData.Get(descriptionid, Ext.Enums.ExtResourceManagerType.FeatDescription)
        local id = description.FeatId
        if featSet[id] ~= nil then
            local spec = featSet[id].Spec
            featSet[id] = E6_MakeFeatInfo(id, spec, description)
        end
    end

    return featSet
end

---@param feat FeatType The feat to test for
---@param entity EntityHandle The entity to test against
---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
---@param onMet function The function to call if the requirement is met. Only called once.
---@param onFilter function The function to call if the requirement is not met, which takes the FeatType and FeatMessageType. May be called multiple times.
local function FeatRequirementTest(feat, entity, playerInfo, onMet, onFilter)
    if not feat.CanBeTakenMultipleTimes and playerInfo.PlayerFeats[feat.ID] ~= nil then
        onFilter(feat, ToMessageLoca("ha0a03263g1b55g40c2g8a7fg5313663ee3a5")) -- The feat has already been selected.
        return
    end

    if not feat.HasRequirements then
        onMet(feat)
        return
    end

    local isMet = true
    for _, req in ipairs(feat.HasRequirements) do
        local met, message = req(entity, playerInfo)
        if not met then
            onFilter(feat, message)
            isMet = false
        end
    end
    if isMet then
        onMet(feat)
    end
end

---Determines if the character meets the requirements for a feat.
---@param feat FeatType The feat to test for
---@param entity EntityHandle The entity to test against
---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
---@return FeatMessageType[] The reasons why the feat requirements were not met.
function GatherFailedFeatRequirements(feat, entity, playerInfo)
    local results = {}
    FeatRequirementTest(feat, entity, playerInfo, function(feat)
    end, function(feat, message)
        table.insert(results, message)
    end)
    return results
end

---Gathers the feats that the player can select. It checks constraints server side as client doesn't
---seem to have all the data to do so.
---@param entity EntityHandle The player entity to test against.
---@param playerInfo PlayerFeatRequirementInformationType Information about what the player has for abilities, proficiencies, etc.
---@return string[] The collection of feats the player can actually select
---@return string[] The collection of feats that were filtered out due to requirements.
function GatherSelectableFeatsForPlayer(entity, playerInfo)
    local allFeats = E6_GatherFeats()

    local featList = {}
    local filtered = {}
    local visited = {}
    for featId, feat in pairs(allFeats) do
        FeatRequirementTest(feat, entity, playerInfo, function(feat)
            table.insert(featList, featId)
        end, function(feat, message)
            if not visited[featId] then
                visited[featId] = true
                table.insert(filtered, featId)
            end
        end)
    end
    return featList, filtered
end

